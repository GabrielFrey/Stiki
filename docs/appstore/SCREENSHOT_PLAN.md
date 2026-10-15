# Screenshot plan

Official required sizes from [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) (fetched 15 Oct 2026). JPEG / JPG / PNG. **No alpha channel.** 1–10 screenshots per device size.

## Required for this app

Stiki is iPhone + iPad (`TARGETED_DEVICE_FAMILY: 1,2`).

| Set | Status | Accepted pixel sizes (portrait) |
|---|---|---|
| iPhone with Dynamic Island (medium display) | **Required** | **1179 × 2556** or **1206 × 2622** |
| iPad 13-inch | **Required** (app runs on iPad) | **2064 × 2752** or **2048 × 2732** |

Other iPhone/iPad sizes scale down from these if you omit them.

**iPhone Duo** (1398 × 2034 outer / 2007 × 2853 inner, plus landscape pairs): optional today. Apple’s 5 Oct 2026 news post says Duo screenshots become required in **April 2027** for apps using the **iOS 27.1 SDK or later**. Stiki’s current target is iOS 26, so Duo is **not required for this submission**. Re-check if you bump the SDK.

**App preview videos:** optional (up to three per size/language). Not required.

**iMessage:** the version page still has an iMessage App screenshot well ([Add iMessage app information](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-imessage-app-information)). The 2026 screenshot-spec table does **not** list a separate iMessage pixel grid. Upload Messages-extension shots into that well using the same iPhone/iPad sizes unless App Store Connect shows a different well. **Confirm on a Mac.**

Guideline 2.3.3: show the app **in use**, not a splash or login. Stiki has no login. 2.3.8: metadata imagery should stay appropriate for 4+. 2.3.9: do not use a real person’s identifiable photos without rights — the UI-test fixtures are synthetic circles.

Do **not** put WhatsApp or Telegram logos on marketing screenshots (Guideline 5.2).

## Sequence (six frames)

Use the same order on iPhone and iPad. Localized captions below are for optional text overlays or for App Store Connect notes — ASC does not have a per-screenshot caption field. If you overlay text, keep it accurate (2.3).

| # | Screen | How to reach with fixtures | Caption EN | Caption RU | Caption HE |
|---|---|---|---|---|---|
| 01 | Library | Launch with `-UITestSample` | Your stickers, still re-editable | Стикеры, которые можно править снова | המדבקות שלכם, עדיין ניתנות לעריכה |
| 02 | Packs | Packs tab | Three free packs. Pro unlocks more. | Три бесплатных пака. Pro снимает лимит. | שלוש חבילות חינם. Pro פותח עוד. |
| 03 | Pack detail | Open **UI Test Pack** | Readiness per destination, then export | Готовность по назначениям — и экспорт | מוכנות לפי יעד, ואז ייצוא |
| 04 | Create | Create tab | Import a photo and cut on device | Импорт фото и вырезание на устройстве | ייבוא תמונה וחיתוך במכשיר |
| 05 | Settings | Settings tab | No account. Optional iCloud for Pro. | Без аккаунта. iCloud — по желанию в Pro. | בלי חשבון. iCloud אופציונלי ב־Pro. |
| 06 | Paywall | Upgrade to Pro | Pay once or once a year. Restore anytime. | Один раз или раз в год. Восстановление всегда. | פעם אחת או פעם בשנה. שחזור בכל עת. |

Frame 06 is also the **IAP App Review screenshot** (upload on each product record).

Optional seventh: iMessage extension browser after the host app has written the App Group catalog.

## Fastlane-free capture (Mac + Xcode 26)

This Linux environment cannot run Simulator. On a Mac:

```bash
cd /path/to/stiki
chmod +x scripts/capture-screenshots.sh
# Override destinations if `xcodebuild -scheme Stiki -showdestinations` differs:
# IPHONE_DEST='platform=iOS Simulator,name=iPhone 16 Pro' \
# IPAD_DEST='platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
./scripts/capture-screenshots.sh
```

What the script does:

1. `xcodegen generate` if XcodeGen is installed.
2. Runs **only** `StikiUITests/ScreenshotCaptureTests` (skipped in the normal suite unless `SCREENSHOT_DIR` is set via `TEST_RUNNER_SCREENSHOT_DIR`).
3. Seeds three stickers with `-UITestSample` so PhotosPicker is not required.
4. Writes a `.xcresult` and tries `xcresulttool export attachments`.
5. Uses `sips` to drop alpha and resize to 1179×2556 (iPhone) and 2064×2752 (iPad).

If `xcresulttool export attachments` fails on your Xcode 26 build, open the `.xcresult` in Xcode and save the screenshot attachments. That flag was **not executed here**.

Manual fallback:

```bash
xcodegen generate
xcrun simctl boot "iPhone 17 Pro"   # name from `xcrun simctl list`
# Install and launch Debug with:
xcodebuild -scheme Stiki -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
xcrun simctl launch booted com.stiki.app -UITestSample
xcrun simctl io booted screenshot docs/screenshots/iphone/01-library.png
# Navigate by hand, repeat screenshot. Then:
sips -z 2556 1179 docs/screenshots/iphone/01-library.png
```

Output folder (gitignored if you want — not ignored by default): `docs/screenshots/iphone/` and `docs/screenshots/ipad/`.

**Status:** capture test and script are in the repo. **No screenshots have been produced in this environment.** You must run the script on a Mac and inspect every frame before upload.
