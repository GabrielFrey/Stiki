import Foundation
import Observation
import StikiCore
import SwiftUI
import UniformTypeIdentifiers

/// Owns the Create tab: import → cutout → editor → save.
@MainActor
@Observable
final class CreateViewModel {
    var step: CreateStep = .importSource
    var session: CreateSession?
    var isImporting = false
    var error: StikiError?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Starts a new sticker from still-image bytes.
    func importStill(_ data: Data, kind: AssetRef.Kind = .image) async {
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            let image = try ImageCoding.decodeNormalized(
                data: data,
                maxPixelSide: SizeFitting.maximumProcessingSide
            )
            let png = try ImageCoding.encode(image, as: .png)
            let ref = try await environment.assetStore.writeAsset(
                png,
                kind: kind,
                pixelSize: image.pixelSize,
                fileExtension: "png"
            )
            let recipe = EditRecipe(source: ref)
            session = CreateSession(recipe: recipe, sourcePreview: png)
            step = .cutout
            await analyze()
        } catch let error as StikiError {
            self.error = error
        } catch {
            self.error = .imageDecodingFailed
        }
    }

    /// Starts a new sticker from a video or Live Photo paired video.
    func importVideo(_ data: Data) async {
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            guard environment.isPro else {
                self.error = .proRequired
                return
            }
            let duration = try await environment.animation.duration(of: data)
            let spec = AnimationService.clampedSpec(
                startSeconds: 0,
                durationSeconds: min(duration, AnimationService.maximumDurationSeconds),
                assetDuration: duration,
                framesPerSecond: 24,
                reusesFirstFrameMask: false
            )
            let frames = try await environment.animation.sampleFrames(
                videoData: data,
                spec: spec
            )
            guard let first = frames.first else { throw StikiError.frameExtractionFailed }
            let png = try ImageCoding.encode(first, as: .png)
            let imageRef = try await environment.assetStore.writeAsset(
                png,
                kind: .image,
                pixelSize: first.pixelSize,
                fileExtension: "png"
            )
            let videoRef = try await environment.assetStore.writeAsset(
                data,
                kind: .video,
                pixelSize: first.pixelSize,
                fileExtension: "mov"
            )
            var recipe = EditRecipe(source: videoRef)
            recipe.animation = spec
            // Keep a still proxy so the editor has something to show immediately.
            recipe.source = videoRef
            session = CreateSession(
                recipe: recipe,
                sourcePreview: png,
                videoData: data
            )
            _ = imageRef
            step = .cutout
            await analyze()
        } catch let error as StikiError {
            self.error = error
        } catch {
            self.error = .frameExtractionFailed
        }
    }

    /// Reopens a library sticker for non-destructive editing.
    func reopen(_ sticker: StickerSnapshot) async {
        error = nil
        guard let recipe = sticker.recipe else {
            error = .assetMissing("recipe")
            return
        }
        do {
            let source = try await environment.assetStore.assetData(recipe.source)
            let preview: Data
            if recipe.source.kind == .image {
                preview = source
            } else {
                let image = try ImageCoding.decodeNormalized(
                    data: source,
                    maxPixelSide: SizeFitting.maximumProcessingSide
                )
                preview = try ImageCoding.encode(image, as: .png)
            }
            session = CreateSession(
                editingStickerID: sticker.id,
                recipe: recipe,
                sourcePreview: preview,
                videoData: recipe.animation == nil ? nil : source
            )
            step = .editor
        } catch {
            self.error = .assetMissing(recipe.source.fileName)
        }
    }

    func analyze() async {
        guard var session else { return }
        session.isBusy = true
        session.error = nil
        self.session = session
        do {
            let analysis = try await environment.subjectLifting.analyze(
                imageData: session.sourcePreview,
                maxPixelSide: SizeFitting.maximumProcessingSide
            )
            session.analysis = analysis
            if let first = analysis.instances.first {
                session.selectedInstances = [first.id]
            }
            session.isBusy = false
            self.session = session
            await rebuildMask()
        } catch let error as StikiError {
            session.isBusy = false
            session.error = error
            self.session = session
        } catch {
            session.isBusy = false
            session.error = .subjectLiftingFailed(error.localizedDescription)
            self.session = session
        }
    }

    func toggleInstance(_ id: Int) async {
        guard var session else { return }
        if session.selectedInstances.contains(id) {
            session.selectedInstances.remove(id)
        } else {
            session.selectedInstances.insert(id)
        }
        self.session = session
        await rebuildMask()
    }

    func keepWholeImage() async {
        guard var session else { return }
        do {
            let size = session.recipe.source.pixelSize
            let mask = try MaskRefinement.wholeImageMask(size: size)
            let png = try ImageCoding.encode(mask, as: .png)
            let ref = try await environment.assetStore.writeAsset(
                png,
                kind: .mask,
                pixelSize: size,
                fileExtension: "png"
            )
            session.recipe.mask = ref
            session.recipe.background = .originalImage
            session.selectedInstances = []
            self.session = session
        } catch {
            session.error = .renderFailed("whole image mask")
            self.session = session
        }
    }

    func rebuildMask() async {
        guard var session, let analysis = session.analysis else { return }
        do {
            let png = try await environment.subjectLifting.mask(
                imageData: session.sourcePreview,
                token: analysis.token,
                instances: session.selectedInstances,
                maxPixelSide: SizeFitting.maximumProcessingSide
            )
            let image = try ImageCoding.decode(data: png)
            let ref = try await environment.assetStore.writeAsset(
                png,
                kind: .mask,
                pixelSize: image.pixelSize,
                fileExtension: "png"
            )
            session.recipe.mask = ref
            self.session = session
        } catch let error as StikiError {
            session.error = error
            self.session = session
        } catch {
            session.error = .subjectLiftingFailed(error.localizedDescription)
            self.session = session
        }
    }

    func applyBrush(strokes: [BrushStroke], feather: Double) async {
        guard var session, let maskRef = session.recipe.mask else { return }
        do {
            let data = try await environment.assetStore.assetData(maskRef)
            let mask = try ImageCoding.decode(data: data)
            let refined = try MaskRefinement.apply(strokes: strokes, to: mask, feather: feather)
            let png = try ImageCoding.encode(refined, as: .png)
            try await environment.assetStore.replaceAsset(png, ref: maskRef)
            session.recipe.mask = maskRef
            self.session = session
        } catch {
            session.error = .renderFailed("brush")
            self.session = session
        }
    }

    func goToEditor() {
        step = .editor
    }

    func save(name: String, emojiTags: [String]) async -> Bool {
        guard let session else { return false }
        do {
            let (source, mask) = try await loadSourceAndMask(session.recipe)
            let canvas = PixelSize.square(618)
            let render: RenderedImage
            if let animation = session.recipe.animation, let video = session.videoData {
                let frames = try await environment.animation.sampleFrames(
                    videoData: video,
                    spec: animation
                )
                let maskImage = try mask.map { try ImageCoding.decode(data: $0) }
                let rendered = try await environment.renderer.renderFrames(
                    recipe: session.recipe,
                    frames: frames,
                    mask: maskImage,
                    canvas: canvas
                )
                render = try await environment.renderer.encodeAnimation(
                    frames: rendered,
                    format: .apng,
                    frameDurationMilliseconds: animation.frameDurationMilliseconds,
                    canvas: canvas,
                    maxBytes: nil,
                    canvasRule: .allowedSquares([300, 408, 618])
                )
            } else {
                render = try await environment.renderer.renderStill(
                    recipe: session.recipe,
                    sourceData: source,
                    maskData: mask,
                    canvas: canvas,
                    format: .png,
                    maxBytes: nil
                )
            }
            _ = try await environment.library.upsertSticker(
                id: session.editingStickerID,
                recipe: session.recipe,
                render: render,
                name: name,
                emojiTags: emojiTags
            )
            reset()
            return true
        } catch let error as StikiError {
            self.error = error
            return false
        } catch {
            self.error = .renderFailed(error.localizedDescription)
            return false
        }
    }

    func reset() {
        session = nil
        step = .importSource
        error = nil
    }

    private func loadSourceAndMask(_ recipe: EditRecipe) async throws -> (Data, Data?) {
        let source: Data
        if recipe.source.kind == .image {
            source = try await environment.assetStore.assetData(recipe.source)
        } else {
            source = session?.sourcePreview ?? Data()
        }
        let mask: Data?
        if let maskRef = recipe.mask {
            mask = try await environment.assetStore.assetData(maskRef)
        } else {
            mask = nil
        }
        return (source, mask)
    }
}
