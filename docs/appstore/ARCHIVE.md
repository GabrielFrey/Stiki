# Archive and upload

Nothing in this file was executed in this Linux environment. There is no Xcode here.

## Versions already set

| Setting | Value | Where |
|---|---|---|
| Marketing version | `1.0` | `project.yml` `MARKETING_VERSION` → `CFBundleShortVersionString` |
| Build | `1` | `CURRENT_PROJECT_VERSION` → `CFBundleVersion` |
| Bundle ID | `com.stiki.app` | App target |
| Messages bundle ID | `com.stiki.app.messages` | Extension |
| App Group | `group.com.stiki.shared` | Both entitlements |
| iCloud container | `iCloud.com.stiki.app` | App entitlements (CloudKit) |
| Deployment target | iOS 26.0 | `project.yml` |
| Encryption key | `ITSAppUsesNonExemptEncryption = false` | App Info.plist |
| StoreKit config in Release bundle | Removed from the app target | Scheme still points at `Configuration.storekit` for Debug |
| UI-test seeding | `#if DEBUG` only | `StikiApp`, `UITestSeeding.swift` |

Bump `CURRENT_PROJECT_VERSION` for every upload. Bump `MARKETING_VERSION` when the user-facing version changes.

## Identifiers you create on developer.apple.com

| Kind | Value | You must |
|---|---|---|
| Team ID | 10 characters | Paste into `Config/exportOptions.plist` and `TEAM_ID` |
| App ID | `com.stiki.app` | Enable App Groups + iCloud + In-App Purchase |
| Extension App ID | `com.stiki.app.messages` | Enable the same App Group |
| App Group | `group.com.stiki.shared` | Both IDs |
| iCloud container | `iCloud.com.stiki.app` | App ID |
| Signing | Automatic in `project.yml` | Select your team in Xcode after `xcodegen generate` |

If the App Group is missing from the profile, the app still launches against the sandbox and Settings shows a warning. **Do not submit that build** — the iMessage extension will be empty.

## Commands (Mac)

```bash
cd /path/to/stiki
xcodegen generate
export TEAM_ID=YOUR_TEAM_ID
./scripts/archive-app-store.sh
```

Equivalent raw commands (Xcode 26):

```bash
xcodebuild -scheme Stiki -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/appstore/Stiki.xcarchive \
  archive

# Replace YOUR_TEAM_ID in Config/exportOptions.plist first.
xcodebuild -exportArchive \
  -archivePath build/appstore/Stiki.xcarchive \
  -exportPath build/appstore/export \
  -exportOptionsPlist Config/exportOptions.plist
```

`Config/exportOptions.plist` uses `method = app-store-connect` (current Xcode name). If `xcodebuild` on your machine rejects it, try `app-store`. That fallback is **unverified** here.

## Upload

Preferred: Xcode Organizer → Distribute App → App Store Connect.

Command-line options Apple still documents:

```bash
# Transporter / iTMSTransporter (GUI or CLI)
xcrun iTMSTransporter -m upload -assetFile build/appstore/export/Stiki.ipa \
  -apiKey "$APP_STORE_API_KEY" -apiIssuer "$APP_STORE_ISSUER_ID"

# altool (legacy wrapper; still referenced in older notes)
xcrun altool --upload-app --type ios \
  --file build/appstore/export/Stiki.ipa \
  --apiKey "$APP_STORE_API_KEY" --apiIssuer "$APP_STORE_ISSUER_ID"
```

Create an App Store Connect API key (Users and Access → Integrations) on a Mac/browser session. **Do not commit the .p8.**

`notarytool` is for Developer ID / Mac notarization, not App Store iOS uploads.

## Release vs Debug checklist before you archive

- [x] `Configuration.storekit` is not in the app target resources
- [x] `UITestSeeding` and the launch `.task` are `#if DEBUG`
- [x] Screenshot UI test skips unless `SCREENSHOT_DIR` is set
- [ ] You selected a Development Team (cannot be done here)
- [ ] You replaced placeholder icons with a final Icon Composer file
- [ ] Privacy / support / terms URLs resolve over HTTPS
- [ ] IAP products are Ready to Submit with review screenshots
