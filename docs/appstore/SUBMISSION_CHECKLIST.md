# App Store submission checklist

Statuses: **Ready in repo** · **Needs Mac** · **Needs Apple account** · **You supply**.

Official guideline text: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) retrieved 15 Oct 2026. This file does not replace a signed-in pass through App Store Connect.

## 4.2 Minimum functionality

| Item | Status | Evidence / gap |
|---|---|---|
| Native app, not a repackaged website | Ready in repo | SwiftUI app + Vision cutout + validator + iMessage extension |
| Lasting utility | Ready in repo | Library, packs, export, re-edit |
| Works without another app (4.2.3.i) | Ready in repo | Messengers are optional export targets |
| Not a commercial template farm (4.2.6) | Ready in repo | Custom Stiki codebase |
| iOS 26 Liquid Glass UI actually runs | **Needs Mac** | Sources compile-checked on Linux only; no Simulator here |
| End-to-end Photos / camera / StoreKit | **Needs Mac** | Device or Simulator |

## 3.1.2 Subscriptions

| Item | Status | Evidence / gap |
|---|---|---|
| Title, length, price in the binary | Ready in repo | `PaywallView` uses StoreKit `displayName` / `displayPrice`; yearly terms state 1 year |
| Restore | Ready in repo | Paywall toolbar + Settings |
| Privacy + Terms links in the binary | Ready in repo | `LegalLinks` + paywall + Settings |
| Privacy + Terms in metadata | Ready in repo (copy) / **You supply** live URLs | `METADATA.md`; enable GitHub Pages or your domain |
| Standard EULA link in the description if you use Apple’s EULA | Ready in repo (copy) | Apple URL in `METADATA.md` and `docs/terms.html` |
| Manage / cancel | Ready in repo | 24-hour copy + `manageSubscriptionsSheet` |
| No weekly bait-and-switch | Ready in repo | Only lifetime + yearly |
| Paid Apps Agreement, IAP records, review screenshots | **Needs Apple account** | `IAP_SETUP.md` |
| 3.1.2(a) “ongoing value” for a yearly lock of the same features as lifetime | Product decision | Be ready to explain iCloud + feature set to Review |

## 5.1.1 Privacy

| Item | Status | Evidence / gap |
|---|---|---|
| Privacy policy URL in metadata | Placeholder | `docs/privacy.html` |
| Privacy policy easily reachable in-app | Ready in repo | Settings → Legal; paywall links |
| Policy identifies data collected (none), third parties (none), retention/deletion | Ready in repo | `docs/privacy.html` |
| Purpose strings for Photos / Camera / Add to Photos | Ready in repo | `project.yml` + `InfoPlist.xcstrings` (en/ru/he) |
| No login required (5.1.1.v) | Ready in repo | Review notes say so |
| Nutrition label = Data Not Collected | Ready in repo (answers) | `PRIVACY_LABEL.md` matches empty `PrivacyInfo.xcprivacy` |
| You paste the label in App Store Connect | **Needs Apple account** | |

## 2.3 Accurate metadata

| Item | Status | Evidence / gap |
|---|---|---|
| Name / subtitle / keywords within limits | Ready in repo | `METADATA.md`; measured |
| Description matches the binary (free vs Pro) | Ready in repo | |
| What’s New describes the first release (2.3.12) | Ready in repo | |
| Screenshots show the app in use (2.3.3) | **Needs Mac** | Script only; no captures yet |
| No prices in name/subtitle/screenshots (2.3.7) | Ready in copy | Keep prices off overlays |
| Keywords are not trademark stuffing (2.3.7) | Ready in copy | No WhatsApp / Telegram / competitor names |
| Category | Ready in copy | Graphics & Design / Photo & Video |
| Age rating questionnaire answered honestly (2.3.6) | Ready in copy | Apple calculates; `METADATA.md` |
| Icon matches the product (2.3.8) | Placeholder | Replace `AppIcon.png` via Icon Composer (**Needs Mac**) |

## 5.2 Intellectual property

| Item | Status | Evidence / gap |
|---|---|---|
| You own or license the icon, sample photos, and copy | **You supply** | Placeholder icon is original geometry generated in-repo; still replace it |
| App name “Stiki” clearance | **You supply** | Trademark search is on you |
| WhatsApp / Telegram **not** in name, subtitle, keywords | Ready in copy | |
| Description mentions messengers only as formats and disclaims affiliation | Ready in copy | Review may still ask for 5.2.2 authorization. WhatsApp documents a third-party sticker pasteboard; keep `net.whatsapp.third-party.sticker-pack` as an implementation detail, not a brand endorsement. |
| No third-party logos on screenshots | **You supply** when capturing | |
| No Apple emoji in the extension (5.2.5) | Ready in repo | Extension shows user stickers, not Apple emoji assets |
| Do not imply Apple endorsement (5.2.4) | Ready in copy | |

## Binary / signing

| Item | Status | Evidence / gap |
|---|---|---|
| Version 1.0 (1) | Ready in repo | `project.yml` |
| Bundle IDs / App Group / iCloud | Ready in repo | Must be created on the portal — **Needs Apple account** |
| Team ID in `exportOptions.plist` | **You supply** | Template `YOUR_TEAM_ID` |
| `ITSAppUsesNonExemptEncryption` = false | Ready in repo | |
| Debug seeding / StoreKit file out of Release | Ready in repo | |
| Archive + upload | **Needs Mac** + **Needs Apple account** | `ARCHIVE.md` |
| Launch screen | Ready in repo | Color-only `UILaunchScreen` |
| All required icon sizes | Placeholder PNGs in repo | Final layered `.icon` **Needs Mac** (Icon Composer, macOS 26.4+) |

## Localization

| Item | Status | Evidence / gap |
|---|---|---|
| App Store metadata en / ru / he | Ready in repo | `METADATA.md` |
| App strings en / ru / he | Ready in repo | Including new paywall legal copy |
| IAP display names en / ru / he | Ready in copy + StoreKit file | Short ASC strings in `IAP_SETUP.md` |
| Runtime RTL / Hebrew | **Needs Mac** | Settings has an RTL preview; not executed here |

## You must supply before clicking Submit

1. Enrolled Apple Developer Program and App Store Connect app record.
2. Team ID, signing certificates, provisioning with App Group + iCloud + IAP.
3. Real legal copyright name.
4. Live HTTPS privacy, support, and terms URLs (GitHub Pages from `docs/` or your domain) and matching `LegalLinks.swift`.
5. Final Icon Composer icon (and regenerated Messages 1024×768).
6. Real screenshots at the required sizes, plus IAP review screenshots.
7. IAP products created, priced, Family Sharing on, review screenshots uploaded, Paid Apps Agreement active.
8. Age-rating form confirmed in the live UI (including any new capability checkboxes).
9. Reviewer contact name, phone, and email.
10. Confirmation that you accept the trademark risk of mentioning WhatsApp/Telegram in the description — or a rewrite that names only “other messaging apps.”

## Honest verification of this pass

**Verified here**

- Official pages listed in `SOURCES.md` (fetched or searched 15 Oct 2026).
- Character/byte counts for name, subtitle, keywords, IAP strings.
- Source review of paywall, Settings legal links, entitlements, privacy manifest, encryption key, DEBUG-only seeding, StoreKit file removed from the app target.
- StikiCore tests were already passing on Linux (72) in an earlier session; not re-run as part of this documentation pass unless noted in the commit.
- Placeholder icons generated and PNG dimensions checked.

**Not verified here**

- `xcodegen`, `xcodebuild`, Simulator, archive, altool, Transporter, Icon Composer.
- App Store Connect live forms, IAP status, screenshot upload, age-rating calculation.
- GitHub Pages DNS (URLs are placeholders).
- A real device Photos / Messages / WhatsApp / Telegram hand-off.
