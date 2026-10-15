# App Store Connect metadata

Copy these fields into App Store Connect. Limits below are from Apple’s product-page and platform-version help (retrieved 15 Oct 2026). Counts were measured in this repo.

| Field | Official limit | Notes |
|---|---|---|
| App name | 30 characters | Guideline 2.3.7 |
| Subtitle | 30 characters | Same guideline + product page |
| Promotional text | 170 characters | Editable without a new version |
| Description | 4000 characters | Plain text; include the standard EULA URL if you use Apple’s EULA |
| Keywords | 100 **bytes** (not characters) | Comma-separated; no spaces after commas; do not repeat the app or company name |
| What’s New | Not re-fetched as a separate byte limit; keep it short and accurate (2.3.12) | First version can describe the launch set |

**Trademarks (Guideline 2.3.7 and 5.2):** do **not** put WhatsApp, Telegram, or other third-party brand names in the name, subtitle, or keywords. The description mentions export interoperability once and states there is no affiliation. Confirm with counsel if you want those brand names in the public description at all.

**URLs (placeholders until GitHub Pages or your domain is live):**

| Field | Placeholder | You must |
|---|---|---|
| Privacy Policy (required) | `https://gabrielfrey.github.io/Stiki/privacy.html` | Enable Pages from `/docs` or replace and update `LegalLinks.swift` |
| Support URL | `https://gabrielfrey.github.io/Stiki/support.html` | Same |
| Marketing URL | `https://gabrielfrey.github.io/Stiki/` | Optional; same host |
| Terms / EULA | Standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` plus `https://gabrielfrey.github.io/Stiki/terms.html` | If you keep Apple’s standard EULA, **put the Apple EULA link in the app description** (App Review 3.1.2 metadata). Custom EULA is uploaded in App Store Connect instead. |

Also set the same Privacy Policy URL in App Information (not only on the version).

**Category:** primary **Graphics & Design**, secondary **Photo & Video**. (Standard App Store category names. Re-check the category picker if Apple renames them.)

**Copyright:** `2026 [Your legal name]`. Do not submit until this is a real person or company name.

**Price:** Free with IAP. Enable Family Sharing on both products.

---

## English (en-US)

**Name:** Stiki  
**Subtitle:** On-device sticker maker  
Counts: name 5 / 30, subtitle 23 / 30.

**Promotional text (112 / 170):**

Cut subjects on device. One pack for iMessage and other messengers. Pay once or once a year — never once a week.

**Keywords (68 / 100 bytes):**

```
sticker,maker,cutout,pack,photo,outline,emoji,gif,webp,editor,export
```

**Description:**

```
Stiki is a sticker maker for iPhone and iPad. Cut a subject out of a photo on the device, keep the original so you can re-edit later, and export one pack to iMessage and to other messaging apps that accept sticker files.

The free plan already includes unlimited static stickers, three packs, every export destination, and no watermark. There is no account and no tracker.

Stiki Pro (optional) unlocks unlimited packs, animated stickers from Live Photos and short video, glow and puffy outlines, extra filters, and optional iCloud sync. Buy Pro once, or as a one-year auto-renewable subscription. There is no weekly plan and no free trial.

Purchases are billed through your Apple ID. The yearly subscription renews automatically unless you turn off auto-renew at least 24 hours before the end of the period. Manage or cancel in Settings → Apple ID → Subscriptions. Restore purchases on any device signed in with the same Apple ID. Family Sharing is enabled.

Privacy Policy: https://gabrielfrey.github.io/Stiki/privacy.html
Terms of Use: https://gabrielfrey.github.io/Stiki/terms.html
Apple Licensed Application EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Stiki is not affiliated with WhatsApp, Telegram, or other third-party messengers. Those names, if you see them in the app, describe file or pasteboard formats only.
```

**What’s New (1.0.0):**

```
First release. On-device cutout, non-destructive edits, pack export, and Stiki Pro as a one-time purchase or yearly subscription.
```

---

## Russian (ru)

**Name:** Stiki  
**Subtitle:** Стикеры на устройстве  
Counts: subtitle 21 characters.

**Promotional text:**

```
Вырезайте объекты на устройстве. Один пак — в iMessage и другие мессенджеры. Один платёж или раз в год, никогда раз в неделю.
```

**Keywords (95 / 100 bytes):**

```
стикер,создать,вырезать,пак,фото,обводка,эмодзи,гиф
```

**Description:**

```
Stiki — приложение для стикеров на iPhone и iPad. Вырежьте объект из фото на устройстве, сохраните исходник для повторного редактирования и экспортируйте один пак в iMessage и в другие мессенджеры, которые принимают файлы стикеров.

Бесплатный тариф уже даёт безлимитные статичные стикеры, три пака, все направления экспорта и без водяного знака. Аккаунта и трекеров нет.

Stiki Pro (по желанию) открывает безлимитные паки, анимированные стикеры из Live Photo и короткого видео, светящуюся и пышную обводку, дополнительные фильтры и опциональную синхронизацию iCloud. Pro можно купить один раз или как годовую автопродлеваемую подписку. Недельного тарифа и пробного периода нет.

Покупки списываются с Apple ID. Годовая подписка продлевается автоматически, если не отключить автопродление минимум за 24 часа до конца периода. Управление: Настройки → Apple ID → Подписки. Восстановление покупок — на любом устройстве с тем же Apple ID. Семейный доступ включён.

Политика конфиденциальности: https://gabrielfrey.github.io/Stiki/privacy.html
Условия использования: https://gabrielfrey.github.io/Stiki/terms.html
Стандартное EULA Apple: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Stiki не связан с WhatsApp, Telegram и другими сторонними мессенджерами. Эти имена, если они встречаются в приложении, обозначают только формат файла или буфера обмена.
```

**What’s New:**

```
Первый выпуск. Вырезание на устройстве, неразрушающее редактирование, экспорт паков и Stiki Pro — разовая покупка или годовая подписка.
```

---

## Hebrew (he)

**Name:** Stiki  
**Subtitle:** יוצר מדבקות במכשיר  
Counts: subtitle 18 characters. Enable right-to-left in App Store Connect for this localization.

**Promotional text:**

```
חיתוך אובייקטים במכשיר. חבילה אחת ל־iMessage ולמסנג'רים אחרים. תשלום אחד או פעם בשנה — לא פעם בשבוע.
```

**Keywords (87 / 100 bytes):**

```
מדבקה,יוצר,חיתוך,חבילה,תמונה,קו,אימוג'י,גיף,עורך
```

**Description:**

```
Stiki הוא יוצר מדבקות ל־iPhone ול־iPad. חתכו אובייקט מתמונה במכשיר, שמרו את המקור לעריכה חוזרת, וייצאו חבילה אחת ל־iMessage וליישומי מסרים אחרים שמקבלים קובצי מדבקות.

המסלול החינמי כבר כולל מדבקות דוממות ללא הגבלה, שלוש חבילות, כל יעדי הייצוא ובלי סימן מים. אין חשבון ואין מעקב.

Stiki Pro (אופציונלי) פותח חבילות ללא הגבלה, מדבקות מונפשות מ־Live Photos ומווידאו קצר, קווי מתאר זוהרים ותפוחים, מסננים נוספים וסנכרון iCloud אופציונלי. אפשר לקנות את Pro פעם אחת או כמנוי שנתי מתחדש. אין מסלול שבועי ואין תקופת ניסיון.

הרכישות מחויבות ל־Apple ID. המנוי השנתי מתחדש אוטומטית אלא אם תכבו חידוש אוטומטי לפחות 24 שעות לפני סוף התקופה. ניהול: הגדרות ← Apple ID ← מנויים. שחזור רכישות בכל מכשיר עם אותו Apple ID. שיתוף משפחתי פעיל.

מדיניות פרטיות: https://gabrielfrey.github.io/Stiki/privacy.html
תנאי שימוש: https://gabrielfrey.github.io/Stiki/terms.html
EULA הסטנדרטי של Apple: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Stiki אינו קשור ל־WhatsApp, ל־Telegram או למסנג'רים אחרים. שמות אלה, אם הם מופיעים ביישום, מתארים פורמט קובץ או לוח בלבד.
```

**What’s New:**

```
גרסה ראשונה. חיתוך במכשיר, עריכה לא הרסנית, ייצוא חבילות, ו־Stiki Pro כרכישה חד-פעמית או כמנוי שנתי.
```

---

## Age rating answers

Fill the questionnaire in App Store Connect. Apple **calculates** the rating from your answers ([Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)). Do not type “4+” as if you chose it.

Documented `AgeRatingDeclaration` attributes (API example on developer.apple.com, 2026) and the answers that match this binary:

| Attribute | Answer |
|---|---|
| alcoholTobaccoOrDrugUseOrReferences | NONE |
| contests | NONE |
| gambling | false |
| gamblingSimulated | NONE |
| horrorOrFearThemes | NONE |
| matureOrSuggestiveThemes | NONE |
| medicalOrTreatmentInformation | NONE |
| profanityOrCrudeHumor | NONE |
| sexualContentGraphicAndNudity | NONE |
| sexualContentOrNudity | NONE |
| unrestrictedWebAccess | false |
| violenceCartoonOrFantasy | NONE |
| violenceRealistic | NONE |
| violenceRealisticProlongedGraphicOrSadistic | NONE |
| kidsAgeBand | null — do **not** select Made for Kids |

The same help page also asks about **in-app controls and capabilities** before the content descriptors. Exact checkbox labels were **not listed** on that page. Recommended answers for this app, **confirm in the live form**:

| Topic (if shown) | Answer | Why |
|---|---|---|
| Advertising | No | No ads |
| Messaging / chat | No | No social inbox |
| Unrestricted web | No | No in-app browser |
| Loot boxes | No | None |
| Parental controls in-app | No | None |
| User-generated content visible to other users | No | Stickers stay on device unless the user exports |
| Age assurance | No | Not implemented |

Expected calculated rating is **4+**, but that is an inference from NONE/false answers, not a verified ASC result.

Use frequency values **NONE / INFREQUENT / FREQUENT**. The API notes that `INFREQUENT_OR_MILD` and `FREQUENT_OR_INTENSE` are deprecated.

---

## Export compliance

`ITSAppUsesNonExemptEncryption` is **false** in the app Info.plist (`project.yml` → `ITSAppUsesNonExemptEncryption: false`).

Stiki uses HTTPS / iCloud / StoreKit encryption provided by the operating system. Apple’s encryption table says apps that use encryption limited to the Apple OS need **no** export documentation. Setting the key to false means “no encryption, or only exempt encryption,” per the `ITSAppUsesNonExemptEncryption` document.

This is **not** legal advice. If you add a non-Apple crypto library later, revisit the questionnaire and the key.
