# App Review notes

Paste into App Store Connect → App Review Information. Not visible to customers. Official help says review notes should stay under 4000 characters.

There is **no login**. Do not ask the reviewer for a username or password.

```
Stiki is an on-device sticker maker. No account. No demo user.

How to try the free app
1. Launch Stiki. Grant Photos only if you want to import a library image; camera is optional.
2. Create tab → pick any photo → cut out a subject → save.
3. Library: reopen the sticker to prove non-destructive edit (source stays on disk).
4. Packs: add stickers (free tier allows three packs). Open a pack and check readiness badges. Auto-fit if a destination is over limit.
5. Export: share sheet, Photos, Files, clipboard, iMessage (extension uses App Group group.com.stiki.shared). Other messengers receive files or pasteboard data only when those apps are installed — they are not required to review the app.

How to try Stiki Pro / StoreKit
Products (must match Configuration.storekit and App Store Connect):
  com.stiki.pro.lifetime   — non-consumable
  com.stiki.pro.yearly     — auto-renewable, P1Y, group “Stiki Pro”

Settings → Upgrade to Pro, or tap a locked Pro control (fourth pack, animation, glow/puffy outline, extra filters, iCloud).
The paywall shows StoreKit displayName, description, displayPrice, yearly auto-renew copy, 24-hour cancel window, Restore, Privacy Policy, Terms of Use, and Manage subscription (system sheet).

Sandbox: use a Sandbox Apple ID. StoreKit Configuration.storekit is attached to the Debug scheme only and is not in the Release bundle. Production/TestFlight builds load products from App Store Connect.

Restore: Settings → Restore purchases, or the paywall toolbar. Same Apple ID.

iCloud sync: Pro only, off by default. Reviewer does not need to enable it. If you do, restart the app after the toggle.

iMessage: open Messages → Apps → Stiki. Stickers appear after the host app has written the App Group catalog. If the extension is empty, create at least one sticker in the host app first.

Encryption: ITSAppUsesNonExemptEncryption = false (OS-provided encryption only).

Contact: use the Support URL on the version. We will answer App Review questions there or via Resolution Center.
```

## Reviewer contact fields

| Field | What to enter | Status |
|---|---|---|
| First / last name | Your name | **You supply** |
| Phone | A number App Review can reach | **You supply** |
| Email | A monitored inbox | **You supply** |
| Demo account | Leave empty; notes say no login | Ready |
| Attachment | Optional IAP paywall screenshot if the IAP record’s review screenshot is not enough | Optional |

## Sign-in required?

No. Guideline 5.1.1(v): if the app does not include significant account-based features, let people use it without a login. Stiki has none.
