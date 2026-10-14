# Requirements traceability

Authoritative spec: `docs/spec.md`. Competitor research (informing, not expanding, scope): `docs/market-research.ru.md`.

Status: **C** complete in source, **P** partial (works with a documented fallback), **B** blocked on a Mac/Xcode/device.

| Spec | Requirement | Implementation | Tests / checks | Status |
|---|---|---|---|---|
| 5.1 | Library grid, context menu, empty state, tabs | `App/Features/Library/LibraryView.swift`, `RootTabView.swift` | UI test seeds library; empty state is the first-run path | C |
| 5.2 | PhotosPicker, camera, paste, Files; 2048 px cap | `ImportView.swift`, `CameraPicker.swift`, `ImageCoding.decodeNormalized`, `SizeFitting.maximumProcessingSide` | Manual on device (Photos/camera entitlements) | C source / B device |
| 5.3 | Vision instance mask, multi-select, person fallback, whole-image, brush + feather | `SubjectLiftingService.swift`, `MaskRefinement.swift`, `CutoutView.swift` | `RenderServiceTests.testBrushAddPaintsWhite`, `testWholeImageMaskIsMostlyOpaque` | C source / B Vision on Linux |
| 5.4 | Non-destructive `EditRecipe`, CoreImage pipeline, undo, gestures, 60 fps CIContext | `EditRecipe` in StikiCore; `RecipePipeline`, `RenderService`, `EditorView` + inspectors | StikiCore recipe round-trip; `RenderServiceTests.testOutlineDilatesTheMask`; `PackMembershipTests` | C |
| 5.5 | Live Photo / video ≤ 3 s, frame sample, per-frame cutout, adaptive encode | `AnimationService.swift`, `CreateViewModel.importVideo`, `ExportService.render` | StikiCore `CompressionPlanTests`; animation sampling needs AVFoundation | C source / B device |
| 5.6 | Packs, reorder, rename, tray, duplicate; edit updates all packs | `StickerLibrary+Packs.swift`, `PacksView.swift`, `PackDetailView.swift` | `PackMembershipTests` | C |
| 5.7 | Validator, readiness badges, auto-fix, WhatsApp pasteboard, Telegram zip, iMessage, Photos, clipboard, ShareLink | `ExportValidator` (StikiCore), `ReadinessBadge`, `ExportService`, `ExportSheet` | 72 StikiCore tests (executed); `ExportProjectionTests` | C; Telegram WebM **P** (GIF fallback, documented) |
| 5.8 | iMessage extension, App Group catalog, pack switcher | `MessagesExtension/StikiMessagesViewController.swift`, `CatalogBuilder`, `SharedCatalog` | SharedCatalog tests (executed) | C source / B Messages runtime |
| 5.9 | StoreKit 2 lifetime + yearly, restore, honest paywall, Configuration.storekit | `PurchaseService.swift`, `PurchaseStore.swift`, `PaywallView.swift`, `Configuration.storekit` | `PurchaseServiceTests` (written; needs StoreKitTest on Mac) | C source / B StoreKit |
| 5.10 | Settings: Pro, restore, iCloud toggle, default target, privacy, about | `SettingsView.swift`, `AppSettings.swift` | RTL preview on Settings | C |
| 4 | Liquid Glass APIs, Reduce Transparency/Motion, Tool palette morph | `App/DesignSystem/*` | Visual, on iOS 26 simulator | C source / B simulator |
| 6 | en / ru / he string catalogs, RTL, VoiceOver, Dynamic Type | `Localizable.xcstrings`, `InfoPlist.xcstrings`, leading/trailing, a11y labels | Catalog present; RTL preview; runtime unverified | C source / B device |
| 7 | Usage descriptions, PrivacyInfo.xcprivacy, App Group | `project.yml` info/entitlements, `PrivacyInfo.xcprivacy` | Files exist | C |
| 8 | StikiCore tests, app tests, UI test, sample PNG | `Packages/StikiCore/Tests`, `Tests/StikiTests`, `Tests/StikiUITests` | **Executed:** `swift test` in StikiCore (72 passed). **Written, not executed:** app XCTest + UITest (no Xcode here) | P |
| 9 | XcodeGen project.yml, four targets, StikiCore package, scheme + StoreKit | `project.yml` | YAML present; `xcodegen generate` not run (no XcodeGen on Linux) | C source / B Mac |
| 10 | README with Mac steps, limits table, mermaid | `README.md` | — | C |

## Documented assumptions

1. **Telegram animated WebM / VP9** is not encoded on device. ImageIO has no WebM destination. Export falls back to GIF (or animated WebP) and tells the user to finish in @Stickers. Static Telegram is WebP/PNG as specified.
2. **WebP writing** is probed at runtime via `CGImageDestinationCopyTypeIdentifiers()`. If absent, PNG/GIF are used. No `libwebp` binary is vendored.
3. **CloudKit** is wired (`ModelConfiguration(cloudKitDatabase:)`) but defaults to `.none` until a Pro user enables it in Settings. Changing the toggle requires an app restart to rebuild the container.
4. **App Group missing from the profile** does not crash launch; files fall back to Application Support and Settings surfaces the iMessage warning.
5. **UI test** cannot drive `PhotosPicker` deterministically, so it launches with `-UITestSample` to seed three stickers and a WhatsApp-ready pack, then asserts the Packs UI.

## Toolchain used in this environment

- Host: Ubuntu 24.04, x86_64, **no Xcode**, **no `xcodebuild`**, **no XcodeGen**.
- Swift **6.2** (official Ubuntu 24.04 tarball) used only for `Packages/StikiCore`.
- App/extension sources were **syntax-parsed where the Linux toolchain could import the module**; they were **not** compiled for iOS.
