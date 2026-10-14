import CoreImage
import CoreVideo
import Foundation
import StikiCore
import Vision
import os

/// Result of analysing an image for liftable subjects.
struct SubjectAnalysis: Sendable {
    /// Token identifying the cached Vision session that produced this result.
    var token: UUID
    /// Instances in the order Vision reported them.
    var instances: [SubjectInstance]
    /// Size of the image the analysis ran on, after import downscaling.
    var imagePixelSize: PixelSize
    /// `true` when no instance was found and a person-segmentation fallback
    /// produced the mask instead.
    var usedPersonSegmentationFallback: Bool

    var hasSubjects: Bool { !instances.isEmpty }
}

/// One liftable subject, with a low-resolution mask for the selection overlay.
struct SubjectInstance: Sendable, Identifiable, Hashable {
    /// Vision instance label; `0` is the background and is never included.
    var id: Int
    /// Low-resolution mask PNG used to draw the glowing selection overlay.
    var previewMaskPNG: Data
    /// Share of the image this instance covers, used to sort and to pick a
    /// sensible default selection.
    var coverage: Double
}

/// On-device subject lifting.
protocol SubjectLifting: Sendable {
    func analyze(imageData: Data, maxPixelSide: Int) async throws -> SubjectAnalysis
    /// Full-resolution grayscale mask (white keeps pixels) for a selection.
    func mask(
        imageData: Data,
        token: UUID?,
        instances: Set<Int>,
        maxPixelSide: Int
    ) async throws -> Data
}

/// Vision-backed implementation.
///
/// Runs entirely on device: `VNGenerateForegroundInstanceMaskRequest` is the
/// same family of request Photos uses for "lift subject", so quality matches
/// the system experience without a server round trip or an account.
///
/// The actor caches the request handler and observation between the analysis
/// pass and mask generation, because `generateScaledMaskForImage(forInstances:
/// from:)` must be given the handler that produced the observation.
actor VisionSubjectLiftingService: SubjectLifting {
    private struct Session {
        var token: UUID
        var handler: VNImageRequestHandler
        var observation: VNInstanceMaskObservation
        var imagePixelSize: PixelSize
    }

    private var session: Session?
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let logger = Logger(subsystem: "com.stiki.app", category: "SubjectLifting")

    func analyze(
        imageData: Data,
        maxPixelSide: Int = SizeFitting.maximumProcessingSide
    ) async throws -> SubjectAnalysis {
        try Task.checkCancellation()
        let image = try ImageCoding.decodeNormalized(data: imageData, maxPixelSide: maxPixelSide)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()

        do {
            try handler.perform([request])
        } catch {
            logger.error("Vision request failed: \(error.localizedDescription, privacy: .public)")
            throw StikiError.subjectLiftingFailed(error.localizedDescription)
        }
        try Task.checkCancellation()

        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            // No distinct instances: fall back to person segmentation, and if
            // that finds nothing either the UI offers "keep whole image".
            let token = UUID()
            session = nil
            let hasPerson = (try? personSegmentationMask(image: image)) != nil
            return SubjectAnalysis(
                token: token,
                instances: [],
                imagePixelSize: image.pixelSize,
                usedPersonSegmentationFallback: hasPerson
            )
        }

        let token = UUID()
        session = Session(
            token: token,
            handler: handler,
            observation: observation,
            imagePixelSize: image.pixelSize
        )

        var instances: [SubjectInstance] = []
        for instance in observation.allInstances {
            try Task.checkCancellation()
            // The low-resolution mask is enough for the tap-to-select overlay
            // and avoids a full-size generation per instance.
            guard let buffer = try? observation.generateMask(forInstances: IndexSet(integer: instance)),
                  let png = try? pngData(from: buffer) else {
                continue
            }
            instances.append(
                SubjectInstance(
                    id: instance,
                    previewMaskPNG: png,
                    coverage: Self.coverage(of: buffer)
                )
            )
        }

        guard !instances.isEmpty else { throw StikiError.noSubjectFound }
        return SubjectAnalysis(
            token: token,
            instances: instances.sorted { $0.coverage > $1.coverage },
            imagePixelSize: image.pixelSize,
            usedPersonSegmentationFallback: false
        )
    }

    func mask(
        imageData: Data,
        token: UUID?,
        instances: Set<Int>,
        maxPixelSide: Int = SizeFitting.maximumProcessingSide
    ) async throws -> Data {
        try Task.checkCancellation()

        if let session, session.token == token, !instances.isEmpty {
            let indexes = IndexSet(instances)
            do {
                let buffer = try session.observation.generateScaledMaskForImage(
                    forInstances: indexes,
                    from: session.handler
                )
                return try pngData(from: buffer)
            } catch {
                logger.error("Scaled mask failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Either the session expired (the actor was recreated, or the user came
        // back to an old sticker) or there were no instances at all.
        let image = try ImageCoding.decodeNormalized(data: imageData, maxPixelSide: maxPixelSide)
        if !instances.isEmpty {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            if let observation = request.results?.first {
                let available = observation.allInstances
                let requested = IndexSet(instances.filter { available.contains($0) })
                let indexes = requested.isEmpty ? available : requested
                let buffer = try observation.generateScaledMaskForImage(
                    forInstances: indexes,
                    from: handler
                )
                session = Session(
                    token: token ?? UUID(),
                    handler: handler,
                    observation: observation,
                    imagePixelSize: image.pixelSize
                )
                return try pngData(from: buffer)
            }
        }
        return try personSegmentationMask(image: image)
    }

    // MARK: - Fallbacks

    /// Person segmentation, used when no foreground instance is found.
    private func personSegmentationMask(image: CGImage) throws -> Data {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw StikiError.noSubjectFound
        }
        // The person mask comes back at the model's resolution; scale it up to
        // the working image so the recipe's mask and source always align.
        return try pngData(
            from: observation.pixelBuffer,
            scaledTo: PixelSize(width: image.width, height: image.height)
        )
    }

    // MARK: - Pixel buffer conversion

    /// Converts a Vision mask buffer into an 8-bit PNG.
    ///
    /// Masks leave the actor as `Data` on purpose: `CVPixelBuffer` is mutable
    /// shared state, so keeping it inside the actor removes a whole class of
    /// concurrency bugs, and PNG masks are small and cheap to cache on disk
    /// for brush refinement.
    private func pngData(from buffer: CVPixelBuffer, scaledTo size: PixelSize? = nil) throws -> Data {
        var ciImage = CIImage(cvPixelBuffer: buffer)
        if let size, !size.isEmpty {
            let scaleX = Double(size.width) / ciImage.extent.width
            let scaleY = Double(size.height) / ciImage.extent.height
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw StikiError.subjectLiftingFailed("mask conversion")
        }
        return try ImageCoding.encode(cgImage, as: .png)
    }

    /// Fraction of the mask that is foreground, sampled on the CPU.
    private static func coverage(of buffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0 else { return 0 }

        let pointer = base.assumingMemoryBound(to: UInt8.self)
        // Sampling every fourth pixel is plenty for ordering instances by size
        // and keeps this off the critical path for large images.
        let step = 4
        var covered = 0
        var sampled = 0
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                sampled += 1
                if pointer[y * bytesPerRow + x] > 127 { covered += 1 }
            }
        }
        return sampled == 0 ? 0 : Double(covered) / Double(sampled)
    }
}
