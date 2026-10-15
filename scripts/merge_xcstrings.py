#!/usr/bin/env python3
"""Insert or replace Localizable.xcstrings entries. Stdlib only."""

from __future__ import annotations

import json
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[1] / "App/Resources/Localizable.xcstrings"


def unit(en: str, ru: str, he: str) -> dict:
    return {
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "ru": {"stringUnit": {"state": "translated", "value": ru}},
            "he": {"stringUnit": {"state": "translated", "value": he}},
        }
    }


STRINGS = {
    "Billed %@ once a year. Auto-renews until you cancel.": unit(
        "Billed %@ once a year. Auto-renews until you cancel.",
        "Списывается %@ раз в год. Автопродление, пока не отмените.",
        "חיוב %@ פעם בשנה. מתחדש אוטומטית עד הביטול.",
    ),
    "Stiki Pro — Yearly": unit(
        "Stiki Pro — Yearly",
        "Stiki Pro — на год",
        "Stiki Pro — שנתי",
    ),
    "Auto-renewable subscription. Length: 1 year. Price: the yearly button above shows the amount billed in your storefront currency. Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless you turn off auto-renew at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions, or tap Manage subscription below.": unit(
        "Auto-renewable subscription. Length: 1 year. Price: the yearly button above shows the amount billed in your storefront currency. Payment is charged to your Apple ID at confirmation. The subscription renews automatically unless you turn off auto-renew at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours prior to the end of the current period. Manage or cancel in Settings → Apple ID → Subscriptions, or tap Manage subscription below.",
        "Автопродлеваемая подписка. Срок: 1 год. Цена: кнопка «на год» выше показывает сумму в валюте вашего магазина. Оплата списывается с Apple ID при подтверждении. Подписка продлевается автоматически, если не отключить автопродление минимум за 24 часа до конца периода. Счёт списывается за продление в течение 24 часов до конца периода. Управление и отмена: Настройки → Apple ID → Подписки или «Управлять подпиской» ниже.",
        "מנוי מתחדש אוטומטית. משך: שנה. מחיר: כפתור השנתי למעלה מציג את הסכום במטבע החנות שלכם. החיוב נעשה ל־Apple ID באישור. המנוי מתחדש אוטומטית אלא אם תכבו חידוש אוטומטי לפחות 24 שעות לפני סוף התקופה. החשבון מחויב על החידוש בתוך 24 השעות שלפני סוף התקופה. ניהול או ביטול ב־הגדרות ← Apple ID ← מנויים, או ב«ניהול מנוי» למטה.",
    ),
    "Manage subscription": unit(
        "Manage subscription",
        "Управлять подпиской",
        "ניהול מנוי",
    ),
    "Opens Apple's subscription management sheet": unit(
        "Opens Apple's subscription management sheet",
        "Открывает системный экран управления подписками Apple",
        "פותח את גיליון ניהול המנויים של Apple",
    ),
    "Privacy Policy": unit(
        "Privacy Policy",
        "Политика конфиденциальности",
        "מדיניות פרטיות",
    ),
    "Terms of Use": unit(
        "Terms of Use",
        "Условия использования",
        "תנאי שימוש",
    ),
    "Support": unit(
        "Support",
        "Поддержка",
        "תמיכה",
    ),
    "Legal": unit(
        "Legal",
        "Правовая информация",
        "משפטי",
    ),
    "No ads, no account, no weekly plan. Purchases are handled by Apple. Family Sharing is on. Restore purchases if you already bought Pro on this Apple ID.": unit(
        "No ads, no account, no weekly plan. Purchases are handled by Apple. Family Sharing is on. Restore purchases if you already bought Pro on this Apple ID.",
        "Без рекламы, без аккаунта, без недельного тарифа. Покупки проводит Apple. Семейный доступ включён. Восстановите покупки, если Pro уже куплен на этом Apple ID.",
        "בלי פרסומות, בלי חשבון, בלי מסלול שבועי. הרכישות עוברות דרך Apple. שיתוף משפחתי פעיל. שחזרו רכישות אם כבר קניתם Pro ב־Apple ID הזה.",
    ),
}


def main() -> None:
    data = json.loads(CATALOG.read_text())
    data["strings"].update(STRINGS)
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"merged {len(STRINGS)} keys into {CATALOG}")


if __name__ == "__main__":
    main()
