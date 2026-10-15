# App icon and launch screen

## What ships today

| Asset | Path | Notes |
|---|---|---|
| iOS App Store / Home Screen source | `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | 1024×1024, opaque RGB, no alpha. Xcode generates device sizes from this single well. |
| iMessage icons | `MessagesExtension/Resources/Assets.xcassets/iMessage App Icon.stickersiconset/` | 1024×768 marketing plus drawer sizes from archived QA1686 (ITMS-90649). |
| Launch screen | `UILaunchScreen` → `LaunchBackground` color | No storyboard. Light cream / dark navy. |

Regenerate placeholders:

```bash
python3 scripts/generate_placeholder_icons.py
```

These are **geometric placeholders** (navy field, blue disc, simple face). Replace them before you submit. Guideline 2.3.8: icon and screenshots should look like the same product.

## iOS 26 Icon Composer (required for a finished Liquid Glass icon)

Official docs: [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) and [Icon Composer](https://developer.apple.com/icon-composer/).

Verified from those pages (15 Oct 2026):

- Icon Composer builds **one multilayer `.icon` file** used across iPhone, iPad, Mac, Watch, and the App Store.
- Design in layers (z-order back to front). Typical canvas **1024 × 1024** for iPhone/iPad/Mac.
- Annotate Default, Dark, and Mono appearances.
- Add the `.icon` file to the Xcode project. Xcode 26 uses it **instead of** an existing `AppIcon` asset catalog when both are present.
- Icon Composer app requires **macOS Tahoe 26.4 or later** (product page).
- For older deployment targets, Xcode can flatten images from the `.icon` at build time. Stiki’s deployment target is **iOS 26**, so the layered icon is the one users see.

This environment **cannot** run Icon Composer. Do this on a Mac:

1. Install Icon Composer from Apple (bundled with recent Xcode / developer downloads).
2. New file, 1024 canvas, at least two layers: background (navy) + foreground (sticker face). Keep a clear middle layer if you want Liquid Glass depth.
3. Preview Default / Dark / Mono. Avoid tiny detail that vanishes at 29 pt.
4. Save as `App/Resources/AppIcon.icon` (or next to the asset catalog).
5. In Xcode, add the file to the Stiki target. Confirm the target App Icon name still matches (`AppIcon`).
6. Keep `AppIcon.png` until the `.icon` builds cleanly; then you can stop relying on the flattened PNG for device rendering. **Still keep a 1024 flattened export** for marketing and for any tool that wants a PNG.
7. Rebuild the iMessage 1024×768 from the same artwork (`scripts/generate_placeholder_icons.py` is only for the placeholder). Icon Composer can export a flattened image for that well.

## Messages icon set

`ASSETCATALOG_COMPILER_APPICON_NAME` for the extension is `iMessage App Icon`. Sizes generated:

| File | Pixels |
|---|---|
| MessagesIcon-1024x768.png | 1024×768 (Messages App Store) |
| MessagesIcon-60x45@2x / @3x | 120×90 / 180×135 |
| MessagesIcon-27x20@2x / @3x | 54×40 / 81×60 |
| MessagesIcon-32x24@2x / @3x | 64×48 / 96×72 |
| MessagesIcon-20x15@2x / @3x | 40×30 / 60×45 |
| MessagesIcon-29x22@2x | 58×44 |
| MessagesIcon-67x50@2x | 134×100 |
| MessagesIcon-74x55@2x | 148×110 |

QA1686 is an **archived** Q&A. If Xcode 26’s iMessage icon set shows different wells, fill those wells and delete unused files. Verify with a TestFlight upload (ITMS-90649 / 90644).

## Launch screen

`project.yml` sets:

```yaml
UILaunchScreen:
  UIColorName: LaunchBackground
```

`LaunchBackground.colorset` is defined for light and dark. No launch image is required. Do not add a marketing splash that looks like a second app (2.3.3).
