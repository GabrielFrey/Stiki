# App Privacy nutrition label

Enter these answers in App Store Connect → App Privacy. They must stay consistent with `App/Resources/PrivacyInfo.xcprivacy` and `docs/privacy.html`.

Official definition ([App Privacy details](https://developer.apple.com/app-store/app-privacy-details/), retrieved 15 Oct 2026):

> “Collect” refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time.

On-device-only processing is **not** collection. Developers are **not** responsible for disclosing data collected by Apple.

## Recommended declaration

**Data Not Collected.**

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No** |
| Privacy Policy URL | `https://gabrielfrey.github.io/Stiki/privacy.html` (replace when live) |
| Privacy Choices URL | Optional; omit, or point at the same privacy page |

`PrivacyInfo.xcprivacy` today:

- `NSPrivacyTracking` = false
- `NSPrivacyTrackingDomains` = empty
- `NSPrivacyCollectedDataTypes` = empty
- Accessed APIs (local): UserDefaults CA92.1, File timestamp C617.1, Disk space E174.1

## Why this matches the binary

| Practice | Collection? | Label |
|---|---|---|
| Vision / Core Image cutout | On device only | Do not declare |
| SwiftData library in the app container or App Group | On device | Do not declare |
| Photos / camera purpose strings | User-initiated, stay on device unless the user exports | Do not declare as collected by us |
| StoreKit purchase | Apple takes payment; we never see card data | Apple: payment info entered outside the app that the developer cannot access is not collected by the developer |
| Optional CloudKit private DB (`iCloud.com.stiki.app`) | User opt-in; Apple hosts the private database; Stiki has no developer server that reads it | Apple: you are not responsible for disclosing data collected by Apple. We still describe the toggle in the privacy policy. |
| Export to Photos / Files / another app | User-initiated hand-off, not our server | Do not declare |
| Analytics / ads / crash SDKs | None in the project | Do not declare |

## Counsel note (do not ignore)

If you later decide that **you** (the developer) can query users’ CloudKit private data through your Apple Developer account in a way that meets Apple’s “collect” definition, you would instead declare **User Content** (Photos or Videos / Other User Content) for **App Functionality**, not linked for tracking. That would also require updating `PrivacyInfo.xcprivacy` and the public policy. The current recommendation is **Data Not Collected** because the shipped code has an empty collected-types array and no developer backend.

Update App Store Connect if practices change. Apple allows privacy-answer edits without a new binary.
