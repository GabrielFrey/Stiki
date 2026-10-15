# Official sources (retrieved 15 October 2026)

Do not treat this folder as a substitute for App Store Connect on a signed-in Mac. Pages below were fetched or searched on that date. Where a help page did not list every form field, that gap is marked **unverified in the live UI**.

| Topic | URL | Used for |
|---|---|---|
| Screenshot specifications | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ | Required iPhone / iPad sizes, JPEG/PNG, no alpha |
| Upload screenshots | https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/ | 1–10 shots, iMessage wells, previews optional |
| iPhone Duo news (5 Oct 2026) | https://developer.apple.com/news/?id=kkphp5qo | Duo screenshots optional now; required April 2027 for iOS 27.1+ SDK |
| Platform version information | https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/ | Promotional text 170 chars; description 4000; keywords 100 **bytes** |
| Product page | https://developer.apple.com/app-store/product-page/ | Name 30; subtitle 30; promo 170 |
| App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ | 2.3, 3.1.2, 4.2, 5.1.1, 5.2 |
| App Privacy details | https://developer.apple.com/app-store/app-privacy-details/ | Definition of “collect”; CloudKit; on-device |
| In-App Purchase information | https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/ | Display name 2–30; description ≤45; review screenshot required |
| Set an app age rating | https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/ | Questionnaire flow; Apple calculates the rating |
| AgeRatingDeclaration example | https://developer.apple.com/documentation/appstoreconnectapi/get-v1-appinfos-_id_-ageratingdeclaration | Documented content-descriptor attributes |
| Export compliance overview | https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/ | Info.plist bypass |
| Encryption documentation table | https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/ | OS-only encryption → no docs |
| `ITSAppUsesNonExemptEncryption` | https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption | `false` = no encryption or only exempt |
| Icon Composer | https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer | Layered `.icon` for iOS 26 |
| Icon Composer product | https://developer.apple.com/icon-composer/ | macOS Tahoe 26.4+ |
| Asset catalog icons | https://developer.apple.com/documentation/xcode/configuring-your-app-icon | 1024 pt iOS well; iMessage 1024×768 |
| Add an app icon | https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/ | Icon ships in the binary |
| Add iMessage app information | https://developer.apple.com/help/app-store-connect/create-an-app-record/add-imessage-app-information | iMessage screenshot well on the version page |
| iMessage icon sizes (archived QA1686) | https://developer.apple.com/library/archive/qa/qa1686/_index.html | 1024×768 + drawer sizes (ITMS-90649) |
| Apple standard EULA | https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ | Linked from paywall + terms |

## Not verified on a Mac in this environment

- Live App Store Connect form labels after 15 Oct 2026 (age-rating “in-app controls” checkboxes beyond the API example).
- Whether iMessage screenshot pixel sizes still duplicate the iPhone/iPad table (the 2026 screenshot spec page has no separate iMessage pixel table; the version page still has an iMessage well).
- `xcodebuild -exportArchive` `method` string on Xcode 26 (`app-store-connect` is used in `Config/exportOptions.plist`; older tools used `app-store`).
- Exact `xcresulttool export attachments` flags on Xcode 26.
