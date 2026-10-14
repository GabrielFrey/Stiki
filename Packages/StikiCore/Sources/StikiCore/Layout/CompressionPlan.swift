import Foundation

/// One encode to try while hunting for a file under the size limit.
public struct CompressionAttempt: Hashable, Sendable {
    public var pixelSize: PixelSize
    /// Lossy quality in `0...1`; ignored by lossless encoders.
    public var quality: Double
    /// Keep every `frameStride`-th frame; `1` keeps them all.
    public var frameStride: Int

    public init(pixelSize: PixelSize, quality: Double, frameStride: Int = 1) {
        self.pixelSize = pixelSize
        self.quality = quality
        self.frameStride = max(1, frameStride)
    }
}

/// Builds the ladder of encodes the exporter walks until the bytes fit.
///
/// The ladder is ordered by how little the user will notice: quality first,
/// then frame thinning, and only then pixel dimensions — and dimensions are
/// skipped entirely for targets that demand an exact canvas, because shrinking
/// a WhatsApp sticker below 512×512 just trades one rejection for another.
public enum CompressionPlan {
    public static let qualityLadder: [Double] = [0.92, 0.84, 0.75, 0.65, 0.55, 0.45]
    public static let scaleLadder: [Double] = [1.0, 0.85, 0.7]
    /// Frame thinning only kicks in once there are enough frames that dropping
    /// some still leaves smooth motion.
    public static let frameStrideLadder: [Int] = [2, 3]
    public static let minimumFramesForThinning = 12

    public static func attempts(
        canvas: CanvasRule,
        baseSize: PixelSize,
        isAnimated: Bool,
        frameCount: Int = 1
    ) -> [CompressionAttempt] {
        let scales = canvasAllowsScaling(canvas) ? scaleLadder : [1.0]
        let lowestQuality = qualityLadder.last ?? 0.45
        var attempts: [CompressionAttempt] = []

        for scale in scales {
            let size = scale == 1.0 ? baseSize : SizeFitting.scaled(baseSize, by: scale)
            for quality in qualityLadder {
                attempts.append(CompressionAttempt(pixelSize: size, quality: quality))
            }
            if isAnimated, frameCount >= minimumFramesForThinning {
                for stride in frameStrideLadder {
                    attempts.append(
                        CompressionAttempt(pixelSize: size, quality: lowestQuality, frameStride: stride)
                    )
                }
            }
        }

        return attempts
    }

    /// Frames left after thinning.
    public static func frameCount(_ frameCount: Int, stride: Int) -> Int {
        guard stride > 1 else { return frameCount }
        return max(1, (frameCount + stride - 1) / stride)
    }

    /// Frame duration that keeps the animation's wall-clock speed after
    /// thinning, clamped to the target's minimum frame duration.
    public static func frameDuration(
        _ duration: Int,
        stride: Int,
        minimumMilliseconds: Int?
    ) -> Int {
        let scaled = max(1, duration * max(1, stride))
        guard let minimum = minimumMilliseconds else { return scaled }
        return max(scaled, minimum)
    }

    /// Frames to keep so an animation fits a duration cap.
    public static func framesFitting(
        durationMilliseconds limit: Int,
        frameDurationMilliseconds frameDuration: Int,
        frameCount: Int
    ) -> Int {
        guard frameDuration > 0 else { return frameCount }
        let fits = limit / frameDuration
        return max(1, min(frameCount, fits))
    }

    private static func canvasAllowsScaling(_ canvas: CanvasRule) -> Bool {
        switch canvas {
        case .exactSquare, .longestSideExactly:
            return false
        case .allowedSquares, .maxLongestSide:
            return true
        }
    }
}
