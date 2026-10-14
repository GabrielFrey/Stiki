import Foundation
import Testing
@testable import StikiCore

@Suite("Export validator")
struct ExportValidatorTests {
    @Test("A conforming pack is ready for WhatsApp")
    func readyPackHasNoIssues() {
        let report = ExportValidator.validate(pack: Fixtures.whatsAppReadyPack(), target: .whatsApp)
        #expect(report.issues.isEmpty)
        #expect(report.readiness == .ready)
        #expect(report.isReady)
    }

    @Test("WhatsApp needs at least three stickers")
    func tooFewStickers() {
        let report = ExportValidator.validate(
            pack: Fixtures.whatsAppReadyPack(stickerCount: 2),
            target: .whatsApp
        )
        #expect(report.issues.contains { $0.problem == .tooFewStickers(count: 2, minimum: 3) })
        // Duplicating a sticker is a safe machine fix, so the pack is amber.
        #expect(report.readiness == .fixable)
        #expect(ExportValidator.fixPlan(for: report).duplicateStickers == 1)
    }

    @Test("WhatsApp rejects packs over thirty stickers and offers no auto-fix")
    func tooManyStickers() {
        let report = ExportValidator.validate(
            pack: Fixtures.whatsAppReadyPack(stickerCount: 31),
            target: .whatsApp
        )
        #expect(report.issues.contains { $0.problem == .tooManyStickers(count: 31, maximum: 30) })
        #expect(report.readiness == .blocked)
        #expect(report.manualIssues.count == 1)
    }

    @Test("Non-512 stickers are flagged with a resize fix", arguments: [
        PixelSize(width: 1024, height: 1024),
        PixelSize(width: 512, height: 384),
        PixelSize(width: 300, height: 300)
    ])
    func wrongCanvasSize(size: PixelSize) {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0].pixelSize = size
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .resize(to: .square(512)) })
        #expect(report.readiness == .fixable)
    }

    @Test("Static stickers over 100 KB are flagged for WhatsApp")
    func staticTooLarge() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0].byteCount = 140 * 1024
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .recompress(maxBytes: 100 * 1024) })
    }

    @Test("Exactly 100 KB is still accepted")
    func staticAtLimit() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0].byteCount = 100 * 1024
        #expect(ExportValidator.validate(pack: pack, target: .whatsApp).isReady)
    }

    @Test("Animated WhatsApp stickers get the 500 KB budget")
    func animatedBudget() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0] = Fixtures.animatedSticker(byteCount: 480 * 1024)
        #expect(ExportValidator.validate(pack: pack, target: .whatsApp).isReady)

        pack.stickers[0] = Fixtures.animatedSticker(byteCount: 520 * 1024)
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .recompress(maxBytes: 500 * 1024) })
    }

    @Test("Frames shorter than 8 ms are slowed down")
    func frameDurationTooShort() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0] = Fixtures.animatedSticker(frameCount: 30, frameDurationMilliseconds: 5)
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .slowFrames(toMilliseconds: 8) })
    }

    @Test("Animations longer than ten seconds are trimmed for WhatsApp")
    func animationTooLongForWhatsApp() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0] = Fixtures.animatedSticker(frameCount: 300, frameDurationMilliseconds: 40)
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .trimAnimation(toMilliseconds: 10_000) })
    }

    @Test("Telegram caps animations at three seconds and 256 KB")
    func telegramAnimationLimits() {
        let pack = PackSpec(
            name: "Loops",
            stickers: [
                StickerSpec(
                    name: "Long",
                    pixelSize: .square(512),
                    byteCount: 300 * 1024,
                    format: .webm,
                    emojiTags: ["😀"],
                    frameCount: 90,
                    frameDurationMilliseconds: 40
                )
            ]
        )
        let report = ExportValidator.validate(pack: pack, target: .telegram)
        #expect(report.issues.contains { $0.autoFix == .trimAnimation(toMilliseconds: 3_000) })
        #expect(report.issues.contains { $0.autoFix == .recompress(maxBytes: 256 * 1024) })
    }

    @Test("Telegram accepts a non-square sticker whose longest side is 512")
    func telegramNonSquare() {
        let pack = PackSpec(
            name: "Tall",
            stickers: [
                StickerSpec(
                    name: "Tall",
                    pixelSize: PixelSize(width: 384, height: 512),
                    byteCount: 60_000,
                    format: .webp,
                    emojiTags: ["😀"]
                )
            ]
        )
        #expect(ExportValidator.validate(pack: pack, target: .telegram).isReady)
    }

    @Test("Telegram requires at least one emoji per sticker")
    func telegramEmojiRequired() {
        let pack = PackSpec(
            name: "Tags",
            stickers: [
                StickerSpec(name: "No tags", pixelSize: .square(512), byteCount: 1_000, format: .webp)
            ]
        )
        let report = ExportValidator.validate(pack: pack, target: .telegram)
        #expect(report.issues.contains { $0.autoFix == .addDefaultEmojiTags(count: 1) })
    }

    @Test("WhatsApp allows at most three emoji per sticker")
    func whatsAppEmojiCeiling() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0].emojiTags = ["😀", "😅", "😂", "🤣"]
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .dropExtraEmojiTags(keeping: 3) })
    }

    @Test("iMessage only accepts its three sticker sizes")
    func iMessageSizes() {
        for side in [300, 408, 618] {
            let pack = PackSpec(
                name: "Messages",
                stickers: [
                    StickerSpec(name: "S", pixelSize: .square(side), byteCount: 90_000, format: .png)
                ]
            )
            #expect(ExportValidator.validate(pack: pack, target: .iMessage).isReady)
        }

        let odd = PackSpec(
            name: "Messages",
            stickers: [
                StickerSpec(name: "S", pixelSize: .square(512), byteCount: 90_000, format: .png)
            ]
        )
        let report = ExportValidator.validate(pack: odd, target: .iMessage)
        #expect(report.issues.contains { $0.autoFix == .resize(to: .square(618)) })
    }

    @Test("iMessage has no tray icon or emoji rules")
    func iMessageHasNoTrayRules() {
        let pack = PackSpec(
            name: "Messages",
            stickers: [
                StickerSpec(name: "S", pixelSize: .square(408), byteCount: 90_000, format: .png)
            ],
            trayIcon: nil
        )
        let report = ExportValidator.validate(pack: pack, target: .iMessage)
        #expect(report.issues.isEmpty)
    }

    @Test("Every shipping target accepts animation, and the still-only rule falls back to a flatten")
    func animationSupport() {
        for target in ExportTarget.allCases {
            #expect(ExportLimits.limits(for: target).supportsAnimation)
        }
        var stillOnly = ExportLimits.iMessage
        stillOnly.animatedFormats = []
        #expect(!stillOnly.supportsAnimation)
        #expect(ValidationProblem.animationNotSupported.autoFix == .flattenAnimation)
    }

    @Test("A missing tray icon blocks WhatsApp but can be generated")
    func missingTrayIcon() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.trayIcon = nil
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .generateTrayIcon(size: .square(96)) })
        #expect(report.readiness == .fixable)
    }

    @Test("Tray icon size, format and weight are all checked")
    func trayIconRules() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.trayIcon = TrayIconSpec(pixelSize: .square(128), byteCount: 60 * 1024, format: .webp)
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(report.issues.contains { $0.autoFix == .generateTrayIcon(size: .square(96)) })
        #expect(report.issues.contains { $0.autoFix == .convertTrayIcon(to: .png) })
        #expect(report.issues.contains { $0.autoFix == .recompressTrayIcon(maxBytes: 50 * 1024) })
    }

    @Test("An unnamed pack needs the user, not a machine")
    func packNameMissing() {
        let report = ExportValidator.validate(
            pack: Fixtures.whatsAppReadyPack(name: "   "),
            target: .whatsApp
        )
        #expect(report.issues.contains { $0.problem == .packNameMissing })
        #expect(report.readiness == .blocked)
    }

    @Test("An overlong name is only a warning")
    func packNameTooLong() {
        let report = ExportValidator.validate(
            pack: Fixtures.whatsAppReadyPack(name: String(repeating: "A", count: 200)),
            target: .whatsApp
        )
        #expect(report.warnings.count == 1)
        #expect(report.errors.isEmpty)
        #expect(report.readiness == .fixable)
        #expect(ExportValidator.fixPlan(for: report).truncateNameTo == 128)
    }

    @Test("Readiness is reported for every badged target")
    func readinessByTarget() {
        let readiness = ExportValidator.readinessByTarget(pack: Fixtures.whatsAppReadyPack())
        #expect(readiness[.whatsApp] == .ready)
        #expect(readiness[.telegram] == .ready)
        #expect(readiness[.iMessage] != nil)
        #expect(readiness.count == 3)
    }

    @Test("An empty pack is blocked for WhatsApp")
    func emptyPack() {
        let report = ExportValidator.validate(
            pack: PackSpec(name: "Empty", stickers: []),
            target: .whatsApp
        )
        #expect(report.issues.contains { $0.problem == .tooFewStickers(count: 0, minimum: 3) })
    }

    @Test("Photos and Files never block an export")
    func photosTargetIsPermissive() {
        let pack = PackSpec(
            name: "Anything",
            stickers: [
                StickerSpec(name: "Huge", pixelSize: .square(2048), byteCount: 4 * 1024 * 1024, format: .png)
            ]
        )
        #expect(ExportValidator.validate(pack: pack, target: .photosAndFiles).isReady)
    }

    @Test("Issue identifiers are stable and unique per sticker and rule")
    func issueIdentifiers() {
        var pack = Fixtures.whatsAppReadyPack()
        pack.stickers[0].pixelSize = .square(1024)
        pack.stickers[0].byteCount = 400 * 1024
        pack.stickers[1].pixelSize = .square(1024)
        let report = ExportValidator.validate(pack: pack, target: .whatsApp)
        #expect(Set(report.issues.map(\.id)).count == report.issues.count)
        #expect(report.issues.allSatisfy { !$0.englishDescription.isEmpty })
    }
}
