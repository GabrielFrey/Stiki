import Foundation
import StikiCore
import UniformTypeIdentifiers
import os

/// Renders a pack to a target's limits and stages the files for hand-off.
///
/// Validation happens first (cheap, no pixels). Rendering and the adaptive
/// compression loop happen here, off the main actor. Opening WhatsApp or the
/// share sheet is a MainActor concern of the view model, because UIPasteboard
/// and UIApplication are main-actor types.
actor ExportService {
    private let renderer: RenderService
    private let assetStore: AssetStore
    private let webPEncoder: any WebPEncoding
    private let logger = Logger(subsystem: "com.stiki.app", category: "Export")

    init(
        renderer: RenderService,
        assetStore: AssetStore,
        webPEncoder: any WebPEncoding = ImageIOWebPEncoder()
    ) {
        self.renderer = renderer
        self.assetStore = assetStore
        self.webPEncoder = webPEncoder
    }

    /// Renders every sticker in `pack` to `target`, applying auto-fixes that
    /// only need a re-encode (resize, recompress, convert, trim, flatten).
    func prepare(
        pack: PackSnapshot,
        target: ExportTarget,
        sourceLoader: @Sendable (StickerSnapshot) async throws -> (source: Data, mask: Data?, frames: [CGImage]?)
    ) async throws -> PreparedExport {
        let limits = ExportLimits.limits(for: target)
        let folder = "\(target.rawValue)-\(pack.id.uuidString.prefix(8))"
        await assetStore.clearExportFolder(folder)

        var rendered: [UUID: RenderedImage] = [:]
        var files: [URL] = []
        var specs: [StickerSpec] = []

        for sticker in pack.stickers {
            try Task.checkCancellation()
            let (source, mask, frames) = try await sourceLoader(sticker)
            let image = try await render(
                sticker: sticker,
                source: source,
                mask: mask,
                frames: frames,
                target: target
            )
            rendered[sticker.id] = image
            let fileName = "\(sticker.id.uuidString).\(image.format.fileExtension)"
            let url = try await assetStore.stageExport(image.data, fileName: fileName, inFolder: folder)
            files.append(url)
            specs.append(
                image.asStickerSpec(
                    id: sticker.id,
                    name: sticker.accessibilityDescription,
                    emojiTags: EmojiTagSuggestions.normalized(
                        sticker.emojiTags,
                        to: limits.emojiTagsRange
                    )
                )
            )
        }

        var tray: RenderedImage?
        if let rule = limits.trayIcon, let cover = pack.coverSticker, let coverRender = rendered[cover.id] {
            let coverImage = try ImageCoding.decode(data: coverRender.data)
            tray = try await renderer.trayIcon(from: coverImage, maxBytes: rule.maxBytes)
            if let tray {
                _ = try await assetStore.stageExport(tray.data, fileName: "tray.png", inFolder: folder)
            }
        }

        let packSpec = PackSpec(
            id: pack.id,
            name: String(pack.name.prefix(limits.maxPackNameLength)),
            stickers: specs,
            trayIcon: tray.map {
                TrayIconSpec(pixelSize: $0.pixelSize, byteCount: $0.byteCount, format: $0.format)
            }
        )
        let report = ExportValidator.validate(pack: packSpec, target: target)
        return PreparedExport(
            target: target,
            report: report,
            files: files,
            trayIcon: tray,
            renderedStickers: rendered
        )
    }

    /// Builds the WhatsApp pasteboard JSON from already-rendered stickers.
    func whatsAppPayload(
        pack: PackSnapshot,
        prepared: PreparedExport,
        publisher: String
    ) throws -> Data {
        guard let tray = prepared.trayIcon else {
            throw StikiError.exportFailed("tray icon")
        }
        let stickers: [WhatsAppPackPayload.Sticker] = pack.stickers.compactMap { snapshot in
            guard let render = prepared.renderedStickers[snapshot.id] else { return nil }
            return WhatsAppPackPayload.Sticker(
                imageData: render.data.base64EncodedString(),
                emojis: EmojiTagSuggestions.normalized(snapshot.emojiTags, to: 1...3)
            )
        }
        let payload = WhatsAppPackPayload(
            identifier: WhatsAppPackPayload.identifier(for: pack.id),
            name: pack.name,
            publisher: publisher,
            trayImageData: tray.data.base64EncodedString(),
            stickers: stickers
        )
        return try payload.serialized()
    }

    /// Zips a Telegram pack (stickers + a README of @Stickers steps).
    func telegramZip(
        pack: PackSnapshot,
        prepared: PreparedExport
    ) async throws -> URL {
        let folder = "telegram-\(pack.id.uuidString.prefix(8))"
        let directory = try await assetStore.exportFolderURL(folder)
        let readme = telegramInstructions(packName: pack.name)
        try readme.data(using: .utf8)?.write(
            to: directory.appending(path: "README.txt", directoryHint: .notDirectory)
        )

        let zipURL = directory.appending(path: "\(sanitized(pack.name)).zip", directoryHint: .notDirectory)
        try await zipContents(of: directory, to: zipURL)
        return zipURL
    }

    func limitations(for target: ExportTarget, isAnimated: Bool) -> [ExportLimitation] {
        var notes: [ExportLimitation] = []
        if target == .telegram, isAnimated {
            notes.append(.telegramWebMUnavailable)
        }
        if (target == .whatsApp || target == .telegram), !webPEncoder.canEncodeStatic {
            notes.append(.webPUnavailable)
        }
        return notes
    }

    // MARK: - Per sticker

    private func render(
        sticker: StickerSnapshot,
        source: Data,
        mask: Data?,
        frames: [CGImage]?,
        target: ExportTarget
    ) async throws -> RenderedImage {
        guard let recipe = sticker.recipe else { throw StikiError.assetMissing("recipe") }
        let limits = ExportLimits.limits(for: target)
        let canvas = limits.canvas.fittedSize(
            for: SizeFitting.squared(recipe.source.pixelSize)
        )
        let wantsAnimation = sticker.isAnimated && limits.supportsAnimation && !(frames?.isEmpty ?? true)
        let format = resolvedFormat(for: target, isAnimated: wantsAnimation)

        if wantsAnimation, let frames, !frames.isEmpty {
            var workingFrames = frames
            if let maxDuration = limits.maxAnimationDurationMilliseconds {
                let keep = CompressionPlan.framesFitting(
                    durationMilliseconds: maxDuration,
                    frameDurationMilliseconds: sticker.frameDurationMilliseconds,
                    frameCount: frames.count
                )
                workingFrames = Array(frames.prefix(keep))
            }
            let maskImage = try mask.map { try ImageCoding.decode(data: $0) }
            let rendered = try await renderer.renderFrames(
                recipe: recipe,
                frames: workingFrames,
                mask: maskImage,
                canvas: canvas
            )
            return try await renderer.encodeAnimation(
                frames: rendered,
                format: format,
                frameDurationMilliseconds: max(
                    sticker.frameDurationMilliseconds,
                    limits.minFrameDurationMilliseconds ?? 0
                ),
                canvas: canvas,
                maxBytes: limits.maxBytes(isAnimated: true),
                canvasRule: limits.canvas
            )
        }

        return try await renderer.renderStill(
            recipe: recipe,
            sourceData: source,
            maskData: mask,
            canvas: canvas,
            format: format,
            maxBytes: limits.maxBytes(isAnimated: false)
        )
    }

    private func resolvedFormat(for target: ExportTarget, isAnimated: Bool) -> StickerFormat {
        let preferred = ExportLimits.limits(for: target).preferredFormat(isAnimated: isAnimated)
        switch preferred {
        case .webp:
            return webPEncoder.canEncodeStatic ? .webp : .png
        case .animatedWebP:
            return webPEncoder.canEncodeAnimated ? .animatedWebP : .gif
        case .webm:
            // No on-device VP9 encoder ships with this build.
            return webPEncoder.canEncodeAnimated ? .animatedWebP : .gif
        default:
            return preferred
        }
    }

    private func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "stickers" : trimmed
        return safe.replacingOccurrences(of: "/", with: "-")
    }

    private func telegramInstructions(packName: String) -> String {
        """
        \(packName)

        1. Open Telegram and start a chat with @Stickers.
        2. Send /newpack (static) or /newvideo (animated).
        3. Send each sticker in this zip, then an emoji for it.
        4. Send /publish when the pack is ready.

        Stiki cannot write WebM on this device, so animated stickers are GIF.
        Convert them with @Stickers if Telegram asks for WebM.
        """
    }

    private func zipContents(of directory: URL, to zipURL: URL) async throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: directory, options: .forUploading, error: &coordinationError) { zip in
            do {
                if FileManager.default.fileExists(atPath: zipURL.path(percentEncoded: false)) {
                    try FileManager.default.removeItem(at: zipURL)
                }
                try FileManager.default.copyItem(at: zip, to: zipURL)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw StikiError.exportFailed(coordinationError.localizedDescription) }
        if let copyError { throw StikiError.exportFailed(copyError.localizedDescription) }
    }
}
