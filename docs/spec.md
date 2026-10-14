# Build "GlassStickers" — an iOS 26 Liquid Glass Sticker Maker (from scratch, new repo)

You are building a production-quality iOS app in an EMPTY repository. You are on Linux and most likely CANNOT run Xcode or `xcodebuild`. Therefore: write complete, compilable Swift 6 code with great care (correct imports, availability, actor isolation, no placeholders/TODO stubs in core paths), keep APIs to ones that exist in the iOS 26 SDK, and generate the Xcode project via **XcodeGen** (`project.yml`) so it builds on a Mac with `xcodegen generate && xcodebuild`. If `swift` is available, run `swift build`/`swift test` on the pure-Swift `StickerCore` package to validate logic.

## 1. Product context (market research summary)
Competitors (WhatSticker, Sticker.ly, Sticker Maker + GIF, "sticker – Sticker Maker", Picsart, Apple Photos Live Stickers) suffer from: predatory weekly subscriptions & fake trials; WhatsApp export failures ("pack too large / wrong dimensions") with no guidance; poor manual cutouts / cloud processing; choppy low-FPS animated stickers; inability to edit a sticker after it's added to a pack; cluttered ad-filled outdated UI; privacy concerns. Apple Photos does great cutouts but has no packs, text, or Telegram export.

**Our differentiators (must be visible in the product):**
1. Native Liquid Glass UI (iOS 26) — floating glass toolbars, morphing controls.
2. On-device Vision subject lifting (multi-subject selection + brush refinement). No server, no account.
3. Animated stickers from Live Photos/videos with smart compression.
4. Export validator: per-target readiness badges (iMessage / WhatsApp / Telegram) and auto-fit to limits.
5. Non-destructive editing: every sticker stores its source + edit recipe and can be re-edited anytime, even inside packs.
6. One pack → all messengers.
7. Fair pricing: generous free tier, no ads, Pro as one-time purchase or yearly. No weekly plans.
8. Privacy-first: "Data Not Collected", local + optional iCloud.

## 2. Tech stack & constraints
- Swift 6, strict concurrency, SwiftUI, deployment target **iOS 26.0** (iPhone + iPad).
- Observation (`@Observable`), MVVM-ish: Views → ViewModels (`@MainActor @Observable`) → Services (protocols, injected via an `AppEnvironment` container).
- Persistence: **SwiftData** (`@Model`), with an App Group container shared with the iMessage extension. Optional CloudKit sync behind a Pro flag (configure `ModelConfiguration(cloudKitDatabase:)` but default `.none`).
- No third-party dependencies in the app target except optionally `libwebp` via SPM for WebP encoding (if added, wrap behind a `WebPEncoder` protocol; provide a fallback that uses ImageIO `UTType.webP` encoding where available — ImageIO supports WebP writing on iOS 26; verify with `CGImageDestinationCopyTypeIdentifiers()` at runtime).
- Bundle ID prefix: `com.glassstickers`. App Group: `group.com.glassstickers.shared`.

## 3. Project structure
```
project.yml                     # XcodeGen
README.md
Packages/StickerCore/           # SPM package, pure Swift + CoreGraphics, testable on Linux where possible
  Sources/StickerCore/
    Models/ (EditRecipe, StickerSpec, ExportTarget, ExportLimits)
    Validation/ExportValidator.swift
    Layout/ (outline geometry helpers, size fitting math)
  Tests/StickerCoreTests/
App/
  GlassStickersApp.swift
  AppEnvironment.swift
  Resources/ (Assets.xcassets, Localizable.xcstrings with en, ru, he, InfoPlist.xcstrings)
  Features/
    Library/        # packs grid, sticker grid
    Import/         # PhotosPicker, camera (UIImagePickerController wrapper / AVFoundation), Files
    Cutout/         # Vision subject lifting UI
    Editor/         # canvas, layers, tools
    Animated/       # Live Photo / video → animated sticker
    Packs/          # pack management, reorder, tray icon
    Export/         # targets, validator UI, share
    Paywall/        # StoreKit 2
    Settings/
  Services/
    SubjectLiftingService.swift  # Vision
    RenderService.swift          # recipe → CGImage/frames
    AnimationService.swift       # AVAssetImageGenerator, frame sampling
    ExportService.swift          # WhatsApp, Telegram, iMessage, PNG/GIF
    PurchaseService.swift        # StoreKit 2
    Storage/ (SwiftData models, AppGroup file store)
  DesignSystem/  # Liquid Glass components
MessagesExtension/  # iMessage sticker app (MSStickerBrowserViewController)
Tests/  GlassStickersTests/ (XCTest / Swift Testing), GlassStickersUITests/
```

## 4. Liquid Glass design system (iOS 26 APIs — use exactly these)
- `.glassEffect(_ glass: Glass = .regular, in: some Shape)`; variants `.regular`, `.clear`, `.identity`; chain `.tint(_:)` and `.interactive()` (only on tappable elements). Apply after layout/appearance modifiers.
- `GlassEffectContainer(spacing:)` around every group of neighboring glass elements (glass can't sample glass).
- Morphing: `@Namespace` + `.glassEffectID(_:in:)`, toggled inside `withAnimation(.bouncy)`.
- Buttons: `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` (primary actions only), `.buttonStyle(.glass(.clear))`.
- Use system `TabView` (gets glass tab bar automatically), `.tabBarMinimizeBehavior(.onScrollDown)`, `ToolbarSpacer`, `.scrollEdgeEffectStyle(_:for:)`, sheets with presentation detents (glass by default). Don't paint opaque backgrounds behind bars.
- Editor: full-bleed canvas with checkerboard/blurred backdrop; a floating bottom `GlassEffectContainer` tool palette that morphs (tap "+" expands into tool buttons: Cutout, Outline, Text, Emoji, Filters, Animate); context-specific glass inspector panel above it.
- Respect `@Environment(\.accessibilityReduceTransparency)` → fall back to `.regularMaterial`/solid; respect Reduce Motion.
- DesignSystem components: `GlassToolPalette`, `GlassIconButton`, `GlassChip`, `ReadinessBadge`, `GlassCard`.

## 5. Features (MVP — all required)
### 5.1 Library
Tabs: Library, Create (+), Packs, Settings. Library shows all stickers (LazyVGrid, context menu: edit, duplicate, add to pack, export, delete). Empty states with onboarding.

### 5.2 Import
`PhotosPicker` (images, Live Photos, videos), camera capture, paste from clipboard, Files. Load via `Transferable`. Downscale large inputs to max 2048 px for processing.

### 5.3 Cutout (on-device)
- `VNGenerateForegroundInstanceMaskRequest`, run off main actor (`actor SubjectLiftingService`). Get `allInstances`; let user tap to toggle instances (show glowing overlay of each); produce mask via `observation.generateScaledMaskForImage(forInstances:from:)` and `generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)`.
- Fallback: `VNGeneratePersonSegmentationRequest` when no instances; "Keep whole image" option (meme mode) with rounded-rect crop.
- Mask refinement: brush add/erase with adjustable size, edge feather slider; mask stored as grayscale PNG in the recipe.

### 5.4 Editor (non-destructive)
`EditRecipe` (Codable, versioned): source asset ref, mask ref, transform, outline (width, color, style: solid / glow / dashed / "puffy" shadow), drop shadow, filters (CoreImage: vivid, mono, comic, posterize, glossy), text layers (font, color, stroke, curved option, position), emoji layers, rotation/scale, background (transparent / color). Rendering via `RenderService` (CoreImage + CoreGraphics): outline = dilate mask (`CIMorphologyMaximum`) + fill color composited under subject. Undo/redo via `UndoManager`. Pinch/rotate gestures on layers. Live preview at 60 fps using cached CIContext (Metal).

### 5.5 Animated stickers
From Live Photo (`PHLivePhoto` paired video) or video ≤ 3 s trimmed: sample frames (AVAssetImageGenerator, 15–30 fps), apply per-frame Vision cutout (batched, with progress + cancel), apply recipe, encode: animated PNG/GIF (ImageIO) for iMessage, animated WebP for WhatsApp, WEBM VP9 note for Telegram (if no encoder available, export Telegram as static WebP / animated as GIF and document limitation). Adaptive compression loop until under size limit.

### 5.6 Packs
SwiftData models: `StickerPack` (name, tray icon, emoji tags per sticker, order, createdAt), `Sticker` (recipe, rendered cache paths, isAnimated). Reorder (drag), rename, tray icon picker, duplicate pack. Editing a sticker updates all packs containing it.

### 5.7 Export + validator (key differentiator)
`ExportLimits` in StickerCore:
- WhatsApp: 512×512 WebP; static ≤100 KB, animated ≤500 KB, frames ≥8 ms, ≤10 s; tray 96×96 PNG ≤50 KB; 3–30 stickers per pack; 1–3 emojis per sticker. Export via `whatsapp://stickerPack` pasteboard JSON (`net.whatsapp.third-party.sticker-pack` pasteboard type) per WhatsApp's iOS sticker spec; add `whatsapp` to `LSApplicationQueriesSchemes`.
- Telegram: 512 px on longest side, static WebP/PNG, animated WEBM ≤256 KB ≤3 s; export as a zip + instructions/deeplink to @Stickers bot, plus share sheet.
- iMessage: PNG/APNG/GIF, ≤500 KB, sizes small/regular/large (300/408/618 pt).
`ExportValidator.validate(pack:target:) -> [ValidationIssue]` with auto-fix suggestions; UI shows `ReadinessBadge` per target (green/amber/red) and "Fix automatically" button.
Also: Save PNG to Photos, copy to clipboard, ShareLink.

### 5.8 iMessage extension
Target `MessagesExtension` (`com.apple.message-payload-provider`), `MSStickerBrowserViewController` subclass reading rendered stickers from the App Group container; pack switcher at top. Main app writes rendered files to App Group on every change.

### 5.9 Paywall (StoreKit 2)
Products: `com.glassstickers.pro.lifetime` (non-consumable), `com.glassstickers.pro.yearly` (auto-renewable). `PurchaseService` actor: load products, purchase, `Transaction.updates` listener, `currentEntitlements`, restore (`AppStore.sync()`). Free: unlimited static stickers, 3 packs, all exports, no watermark, no ads. Pro: unlimited packs, animated stickers, advanced outlines/filters, iCloud sync. Paywall in Liquid Glass, honest copy, no fake trial. Include `Configuration.storekit` file for local testing.

### 5.10 Settings
Pro status, restore, iCloud sync toggle (Pro), default export target, language note, privacy statement, about.

## 6. Localization & accessibility
- String Catalogs with **en, ru, he** — every user-facing string localized (no hardcoded literals). Hebrew RTL: use leading/trailing, test with `.environment(\.layoutDirection, .rightToLeft)` previews.
- VoiceOver labels/hints on every control, Dynamic Type up to AX5 (tool palettes scroll/wrap), sufficient contrast over glass, Reduce Transparency/Motion support, accessible sticker descriptions (use emoji tags as label).

## 7. Privacy & Info.plist
`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSCameraUsageDescription` (localized). Add `PrivacyInfo.xcprivacy` (no tracking, no data collected; declare required-reason APIs e.g. UserDefaults `CA92.1`, file timestamp `C617.1`).

## 8. Testing
- StickerCore: Swift Testing tests for ExportValidator (all limits, edge cases), size fitting, recipe Codable round-trip & versioning.
- App unit tests: RenderService outline on a synthetic mask, PurchaseService with StoreKitTest, pack membership updates.
- One UI test: create sticker from bundled sample image → add to pack → validator shows WhatsApp readiness.
- Bundle a sample image in test resources (generate a simple PNG programmatically if needed).

## 9. project.yml requirements
Targets: `GlassStickers` (app), `GlassStickersMessages` (iMessage extension, embedded), `GlassStickersTests`, `GlassStickersUITests`; local package `StickerCore`. Set `SWIFT_VERSION: 6.0`, `IPHONEOS_DEPLOYMENT_TARGET: 26.0`, `TARGETED_DEVICE_FAMILY: "1,2"`, entitlements (App Groups, iCloud/CloudKit optional), `GENERATE_INFOPLIST_FILE` where appropriate, a shared scheme with tests and the StoreKit configuration.

## 10. README.md
Overview + differentiators, screenshots placeholder, requirements (Xcode 26+, macOS 26, `brew install xcodegen`), build steps (`xcodegen generate`, open or `xcodebuild -scheme GlassStickers -destination 'platform=iOS Simulator,name=iPhone 17' build test`), signing/App Group setup, StoreKit testing, export format limits table, architecture diagram (mermaid), roadmap (v1.1: Image Playground AI stickers, Genmoji-style, widgets, Mac Catalyst).

## 11. Code quality rules
- No force unwraps outside tests; typed errors with localized descriptions.
- Heavy work off the main actor; `Sendable` correctness; cancellation support.
- SwiftUI `#Preview` for each major view with mock services.
- Small files (<300 lines), doc comments on public APIs.
- Commit in logical steps with clear messages.

## 12. Definition of Done
- [ ] Repo contains `project.yml`, all sources, resources, tests, README, `.gitignore` (Xcode/DerivedData), LICENSE (MIT).
- [ ] `xcodegen generate` would succeed (valid YAML, all referenced paths exist).
- [ ] All features in §5 implemented end-to-end (no stub services in the main flow).
- [ ] Liquid Glass APIs used per §4, with Reduce Transparency fallback.
- [ ] en/ru/he localization complete; RTL correct.
- [ ] StickerCore tests pass via `swift test` (if toolchain available); otherwise state clearly in the final report.
- [ ] Final report: summary of what was built, files list, known limitations, and anything that needs verification on macOS.
