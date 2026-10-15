# In-app purchase setup

Create products in App Store Connect that match `Configuration.storekit` and `StikiProductID`.

Official property limits ([In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/), retrieved 15 Oct 2026):

| Property | Limit |
|---|---|
| Product ID | ≤100 characters; letters, numbers, hyphens, periods, underscores; **immutable** after save |
| Reference name | ≤64 characters; internal only |
| Display name | 2–30 characters, localizable |
| Description | ≤45 characters, localizable |
| Review notes | ≤4000 characters |
| App Review screenshot | **Required.** Review only; not shown on the store. Any screenshot size your app supports. Cannot be removed after upload. |
| Promoted IAP image | Optional. 1024×1024 JPEG/PNG, 72 dpi, RGB, flattened, no rounded corners — only if you promote the IAP or use win-back / offer codes |

`Configuration.storekit` localizations can be longer than 45 characters because that file is for local StoreKit testing and the paywall. **Copy the short strings below into App Store Connect**, not the long StoreKit sentences.

Suggested list prices in the StoreKit file (`9.99` lifetime, `4.99` yearly) are **placeholders**. Set real prices per storefront in App Store Connect. Do not put prices in screenshots or the subtitle (Guideline 2.3.7).

## Products

### Lifetime (non-consumable)

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Product ID | `com.stiki.pro.lifetime` |
| Reference name | Stiki Pro (Lifetime) |
| Family Sharing | On (matches StoreKit config) |
| Review screenshot | Paywall with the lifetime button visible (see SCREENSHOT_PLAN) |

Display name / description (≤30 / ≤45 characters):

| Locale | Display name | Description |
|---|---|---|
| English | Stiki Pro — One-Time | Pay once. Unlock every Pro feature. |
| Russian | Stiki Pro — навсегда | Раз и навсегда. Все функции Pro. |
| Hebrew | Stiki Pro — חד-פעמי | תשלום אחד. כל יכולות Pro. |

### Yearly (auto-renewable)

| Field | Value |
|---|---|
| Type | Auto-Renewable Subscription |
| Product ID | `com.stiki.pro.yearly` |
| Reference name | Stiki Pro (Yearly) |
| Subscription group | Stiki Pro (create one group; StoreKit group id `20250101` is local-only) |
| Duration | 1 Year |
| Introductory offer | None |
| Family Sharing | On |

Group localization:

| Locale | Group display name | Group description (ASC group copy; keep factual) |
|---|---|---|
| English | Stiki Pro | Everything in Stiki Pro |
| Russian | Stiki Pro | Всё в Stiki Pro |
| Hebrew | Stiki Pro | הכול ב־Stiki Pro |

Subscription localization:

| Locale | Display name | Description |
|---|---|---|
| English | Stiki Pro — Yearly | Yearly Pro. Auto-renews. Cancel anytime. |
| Russian | Stiki Pro — на год | Pro на год. Автопродление. Отмена. |
| Hebrew | Stiki Pro — שנתי | Pro שנתי. מתחדש. ביטול בכל עת. |

## Subscription group notes

Guideline 3.1.2(b): users must not subscribe to multiple variations of the same thing by accident. Stiki ships **one** auto-renewable product, so there is no upgrade/downgrade ladder. Lifetime is a separate non-consumable; the app treats either as Pro (`PurchaseService`).

Guideline 3.1.2(a) examples of ongoing value include cloud support and substantive updates. Yearly Pro includes optional iCloud sync plus the same feature set as lifetime. Be ready to explain that in Resolution Center if asked. This is a product decision, not something this environment can certify.

## Binary disclosures (already in the paywall)

Verified in source (`PaywallView.swift`, `LegalLinks.swift`, `SettingsView.swift`):

- StoreKit `displayName`, `description`, `displayPrice`
- Yearly auto-renew sentence with the localized price
- Length (1 year), Apple ID charge, 24-hour cancel window, renewal charge window
- Restore purchases
- Privacy Policy and Terms of Use links
- Manage subscription → system `manageSubscriptionsSheet`

You still must add functional Privacy + Terms URLs in **metadata** (description and the Privacy Policy field).

## Review screenshot requirement

Each IAP record needs a screenshot that “clearly shows the item or service being offered.” Capture the paywall on a required device size (see SCREENSHOT_PLAN). Upload that PNG to **both** product records if they share the same screen. This image is for review only.

## Paid Apps Agreement

Agreements, Tax, and Banking must be active before IAP can go Ready to Submit. **You do this in App Store Connect.** Not done from this environment.

## Local testing on a Mac

`Configuration.storekit` is attached to the **Stiki scheme** (`storeKitConfiguration`). It is **not** copied into the Release app bundle. Debug + unit tests can still load it.

```
xcodegen generate
open Stiki.xcodeproj
# Scheme → Run → Options → StoreKit Configuration = Configuration.storekit
```
