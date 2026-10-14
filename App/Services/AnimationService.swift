import AVFoundation
import CoreGraphics
import Foundation
import Photos
import StikiCore
import UniformTypeIdentifiers
import os

/// Progress of a long animation job, reported on the main actor by callers.
struct AnimationProgress: Hashable, Sendable {
    var fraction: Double
    var completedFrames: Int
    var totalFrames: Int
}

/// Samples Live Photos and short videos into sticker frames.
///
/// Frame extraction is the memory-heavy part of animation, so it lives in its
/// own actor: `AVAssetImageGenerator` is cancelled when the Task is, and
/// frames are produced one at a time rather than decoded as a full movie.
actor AnimationService {
    private let logger = Logger(subsystem: "com.stiki.app", category: "Animation")

    /// Longest clip Stiki will animate. Longer videos are trimmed from the
    /// start; the editor then lets the user pick a different window.
    static let maximumDurationSeconds: Double = 3

    /// Reads the duration of a movie without decoding frames.
    func duration(of videoData: Data) async throws -> Double {
        let asset = try temporaryAsset(from: videoData)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    /// Samples `spec` frames from `videoData`.
    func sampleFrames(
        videoData: Data,
        spec: AnimationSpec,
        maxPixelSide: Int = SizeFitting.maximumProcessingSide,
        progress: (@Sendable (AnimationProgress) -> Void)? = nil
    ) async throws -> [CGImage] {
        try Task.checkCancellation()
        let asset = try temporaryAsset(from: videoData)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw StikiError.videoHasNoVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let natural = try await track.load(.naturalSize)
        let longest = max(natural.width, natural.height)
        if longest > CGFloat(maxPixelSide), longest > 0 {
            let scale = CGFloat(maxPixelSide) / longest
            generator.maximumSize = CGSize(width: natural.width * scale, height: natural.height * scale)
        }

        let timestamps = spec.frameTimestamps()
        var frames: [CGImage] = []
        frames.reserveCapacity(timestamps.count)

        for (index, seconds) in timestamps.enumerated() {
            try Task.checkCancellation()
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let cgImage: CGImage = try await withCheckedThrowingContinuation { continuation in
                generator.generateCGImageAsynchronously(for: time) { image, _, error in
                    if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(
                            throwing: error ?? StikiError.frameExtractionFailed
                        )
                    }
                }
            }
            frames.append(cgImage)
            progress?(
                AnimationProgress(
                    fraction: Double(index + 1) / Double(max(timestamps.count, 1)),
                    completedFrames: index + 1,
                    totalFrames: timestamps.count
                )
            )
        }

        guard !frames.isEmpty else { throw StikiError.frameExtractionFailed }
        return frames
    }

    /// Clamps a trim window into the legal animation range.
    static func clampedSpec(
        startSeconds: Double,
        durationSeconds: Double,
        assetDuration: Double,
        framesPerSecond: Int,
        reusesFirstFrameMask: Bool
    ) -> AnimationSpec {
        let safeDuration = min(max(durationSeconds, 0.2), min(assetDuration, maximumDurationSeconds))
        let maxStart = max(0, assetDuration - safeDuration)
        let start = min(max(startSeconds, 0), maxStart)
        let fps = min(max(framesPerSecond, 8), 30)
        return AnimationSpec(
            startSeconds: start,
            durationSeconds: safeDuration,
            framesPerSecond: fps,
            reusesFirstFrameMask: reusesFirstFrameMask
        )
    }

    /// Writes `data` to a unique temp file so `AVURLAsset` can read it.
    ///
    /// PhotosPicker and Files give us bytes, not a security-scoped URL we can
    /// keep, and AVFoundation will not parse a movie from a Data blob.
    private func temporaryAsset(from data: Data) throws -> AVURLAsset {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "stiki-video-\(UUID().uuidString).mov", directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return AVURLAsset(url: url)
    }
}

/// Loads a Live Photo's paired video, or `nil` when the item is a still.
enum LivePhotoVideoLoader {
    static func pairedVideoData(from livePhoto: PHLivePhoto) async -> Data? {
        await withCheckedContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: livePhoto)
            guard let video = resources.first(where: { $0.type == .pairedVideo }) else {
                continuation.resume(returning: nil)
                return
            }
            let buffer = NSMutableData()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().requestData(
                for: video,
                options: options,
                dataReceivedHandler: { chunk in buffer.append(chunk) },
                completionHandler: { error in
                    continuation.resume(returning: error == nil ? buffer as Data : nil)
                }
            )
        }
    }
}
