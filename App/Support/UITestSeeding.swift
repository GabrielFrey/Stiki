import CoreGraphics
import Foundation
import ImageIO
import StikiCore

/// Deterministic library used only by UI tests.
///
/// PhotosPicker cannot be driven reliably, so the UI test launches with
/// `-UITestSample` and this helper inserts three sample stickers in a pack
/// that is WhatsApp-ready. Production launches never call it.
enum UITestSeeding {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestSample")
    }

    @MainActor
    static func seedIfNeeded(in environment: AppEnvironment) async {
        guard isEnabled, !environment.library.hasContent else { return }
        do {
            var ids: [UUID] = []
            for index in 1...3 {
                let data = SamplePNG.circle(side: 128)
                let ref = try await environment.assetStore.writeAsset(
                    data,
                    kind: .image,
                    pixelSize: .square(128),
                    fileExtension: "png"
                )
                let recipe = EditRecipe(source: ref, outline: .default)
                let render = RenderedImage(data: data, pixelSize: .square(512), format: .png)
                let id = try await environment.library.upsertSticker(
                    recipe: recipe,
                    render: render,
                    name: "Sample \(index)",
                    emojiTags: ["😀"]
                )
                ids.append(id)
            }
            let packID = try environment.library.createPack(name: "UI Test Pack", isPro: true)
            for id in ids {
                try environment.library.addSticker(id, toPack: packID)
            }
        } catch {
            // The UI test will fail on missing UI rather than crash launch.
        }
    }
}

/// Tiny PNG encoder used by UI-test seeding without linking the test target.
enum SamplePNG {
    static func circle(side: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let destSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return Data()
        }
        _ = destSpace
        context.setFillColor(red: 0.2, green: 0.6, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fillEllipse(in: CGRect(x: 16, y: 16, width: side - 32, height: side - 32))
        guard let image = context.makeImage() else { return Data() }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
