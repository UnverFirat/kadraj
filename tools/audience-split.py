#!/usr/bin/env python3
"""Katalogu KİŞİSEL / İŞLETME / NÖTR diye sayar ve vitrin sırasına göre döker.

NEDEN VAR: kullanıcı cihaz turunda "şablonlar esnaf işine göre yazılmış, oysa
son kullanıcı kendi fotoğrafından video çıkaracak" dedi (YAPILACAKLAR §0a).
Bu bir konumlandırma kararı ve karar verilmeden önce ÖLÇÜLMESİ istendi.
Betik ölçer; galeri sırasına DOKUNMAZ.

Etiketler aşağıda elle yazılmıştır — tahmin edilemezler, şablonun ne için
tasarlandığına bakmak gerekir. Bir etiketle aynı fikirde değilsen TABLOYU
DÜZELT ve yeniden koş; sayılar da bölüm dağılımı da otomatik güncellenir.

  personal  son kullanıcı kendi hayatını paylaşıyor (doğum günü, gezi, evcil)
  business  bir işletme/esnaf müşterisine sesleniyor (menü, fiyat, ilan)
  neutral   biçim şablonu, iki taraf da aynı şekilde kullanır (kolaj, alıntı)

Kullanım: python3 tools/audience-split.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Vitrin sırası tek kaynaktan okunur; burada kopyalanmaz.
CATEGORY_ORDER_SWIFT = ROOT / "TemplateKit/Sources/TemplateKit/Model/TemplateCategory.swift"

AUDIENCE = {
    # beauty — hepsi salon/işletme: randevu, hizmet fiyatı, öncesi-sonrası vitrini
    "beauty-before-after-01": "business", "hair-color-01": "business",
    "makeup-look-01": "business", "nail-art-01": "business",
    "price-list-01": "business", "salon-booking-01": "business",
    "skincare-steps-01": "business", "spa-calm-01": "business",
    # business
    "headline-01": "business", "logo-reveal-01": "business",
    "product-01": "business", "stat-card-01": "business",
    "team-hiring-01": "business", "testimonial-01": "business",
    "testimonial-quote-01": "business",
    # education — öğrencinin kendi programı kişisel, gerisi kurs/öğretmen
    "course-promo-01": "business", "exam-countdown-01": "personal",
    "lesson-tips-01": "business", "quiz-card-01": "business",
    "student-work-01": "business", "study-plan-01": "personal",
    "webinar-invite-01": "business", "word-of-day-01": "business",
    # fashion — dolap/kombin kişisel, reyon/stok mağaza
    "accessory-01": "business", "capsule-01": "personal",
    "lookbook-01": "personal", "outfit-grid-01": "personal",
    "restock-01": "business", "sale-rack-01": "business",
    "style-tip-01": "business", "try-on-01": "personal",
    # fitness — kendi rekoru/koşusu kişisel, salon programı işletme
    "challenge-01": "personal", "class-schedule-01": "business",
    "gym-offer-01": "business", "nutrition-tip-01": "business",
    "pr-card-01": "personal", "run-stats-01": "personal",
    "transformation-01": "personal", "workout-steps-01": "business",
    # food — tarif kişisel, menü/servis işletme
    "cafe-menu-01": "business", "coffee-shop-01": "business",
    "daily-special-01": "business", "dessert-reveal-01": "business",
    "drinks-list-01": "business", "food-delivery-01": "business",
    "menu-card-01": "business", "recipe-quick-01": "personal",
    "recipe-steps-01": "personal", "restaurant-tour-01": "business",
    # holiday — tamamı kişisel tebrik
    "bayram-greeting-01": "personal", "birthday-wish-01": "personal",
    "mothers-day-01": "personal", "new-year-01": "personal",
    "ramadan-01": "personal", "valentines-01": "personal",
    # minimal — tamamı biçim şablonu
    "bold-statement-01": "neutral", "film-strip-01": "neutral",
    "grade-book-01": "neutral", "minimal-fade-01": "neutral",
    "mono-frame-01": "neutral", "paper-note-01": "neutral",
    "polaroid-01": "neutral", "quote-01": "neutral",
    "soft-gradient-01": "neutral", "typewriter-note-01": "neutral",
    # music — müzisyenin tanıtımı işletme sayılır; çalma listesi kişisel
    "cover-art-01": "business", "gig-poster-01": "business",
    "lyric-card-01": "business", "open-mic-01": "business",
    "playlist-card-01": "personal", "studio-session-01": "business",
    "tour-dates-01": "business", "track-drop-01": "business",
    # promo — tamamı satış
    "bogo-offer-01": "business", "coupon-code-01": "business",
    "flash-discount-01": "business", "free-shipping-01": "business",
    "last-chance-01": "business", "new-arrival-01": "business",
    "sale-promo-01": "business", "split-screen-01": "business",
    # realestate — tamamı ilan/danışman
    "agent-card-01": "business", "for-rent-01": "business",
    "just-sold-01": "business", "new-listing-01": "business",
    "open-house-01": "business", "price-drop-01": "business",
    "property-specs-01": "business", "real-estate-01": "business",
    "room-tour-01": "business",
    # social — "günüm/evcil/geçen yıl" kişisel, grid/liste biçim
    "audiogram-01": "business", "bubble-grid-01": "neutral",
    "caption-bar-01": "neutral", "celebrate-01": "personal",
    "day-in-life-01": "personal", "fast-cut-01": "neutral",
    "grid-four-01": "neutral", "list-five-01": "neutral",
    "music-card-01": "personal", "neon-sign-01": "neutral",
    "pet-star-01": "personal", "photo-dump-01": "personal",
    "poll-card-01": "neutral", "qa-card-01": "neutral",
    "retro-vhs-01": "neutral", "sticker-fun-01": "personal",
    "three-things-01": "neutral", "throwback-01": "personal",
    "typography-01": "neutral", "weekly-recap-01": "personal",
    "zoom-punch-01": "neutral",
    # travel — gezi kişisel; reel kolaj biçim
    "city-guide-01": "personal", "photo-slideshow-01": "personal",
    "reel-collage-01": "neutral", "road-trip-01": "personal",
    "sunset-diary-01": "personal", "travel-checklist-01": "personal",
    "travel-mix-01": "personal", "vlog-intro-01": "personal",
    # wedding — tamamı kişisel kutlama; şekilli çerçeve biçim
    "anniversary-01": "personal", "baby-news-01": "personal",
    "countdown-01": "personal", "engagement-01": "personal",
    "graduation-01": "personal", "invite-card-01": "personal",
    "save-the-date-01": "personal", "shapes-trio-01": "neutral",
}

LABEL = {"personal": "kişisel", "business": "işletme", "neutral": "nötr"}


def gallery_order():
    """`TemplateCategory.order` dizisini Swift kaynağından okur."""
    src = CATEGORY_ORDER_SWIFT.read_text(encoding="utf-8")
    start = src.index("public static let order = [")
    body = src[start:src.index("]", start)]
    return [p.strip().strip('"') for p in body.split("[", 1)[1].split(",")]


def main():
    templates = {}
    for path in sorted((ROOT / "templates").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "category" not in data:
            continue
        name = data["name"]
        templates[data["id"]] = (data["category"],
                                 name.get("tr") if isinstance(name, dict) else name)

    missing = sorted(set(templates) - set(AUDIENCE))
    extra = sorted(set(AUDIENCE) - set(templates))
    if missing:
        print("ETİKETSİZ ŞABLON (tabloya ekle):", ", ".join(missing), file=sys.stderr)
    if extra:
        print("ARTIK OLMAYAN ŞABLON (tablodan sil):", ", ".join(extra), file=sys.stderr)

    order = gallery_order()
    seen = 0
    running = {"personal": 0, "business": 0, "neutral": 0}
    total = {"personal": 0, "business": 0, "neutral": 0}

    print(f"{'#':>2}  {'bölüm':<11} {'n':>3}  {'kişi':>4} {'işl':>4} {'nötr':>4}   "
          f"{'buraya kadar kişisel':>20}")
    print("-" * 68)
    for i, category in enumerate(order, 1):
        ids = [t for t, (c, _) in templates.items() if c == category]
        if not ids:
            continue
        counts = {"personal": 0, "business": 0, "neutral": 0}
        for t in ids:
            counts[AUDIENCE.get(t, "neutral")] += 1
        for k in counts:
            running[k] += counts[k]
            total[k] += counts[k]
        seen += len(ids)
        share = running["personal"] / seen
        print(f"{i:>2}  {category:<11} {len(ids):>3}  {counts['personal']:>4} "
              f"{counts['business']:>4} {counts['neutral']:>4}   "
              f"{running['personal']:>3}/{seen:<3} = %{share * 100:4.0f}")

    n = sum(total.values())
    print("-" * 68)
    for k in ("personal", "business", "neutral"):
        print(f"{LABEL[k]:>8}: {total[k]:>3}  (%{total[k] / n * 100:.0f})")
    print(f"{'toplam':>8}: {n:>3}")

    # Kişisel şablonlar vitrinin neresinde? Kartın kaçıncı sırada göründüğü,
    # kullanıcının onu görmek için ne kadar kaydırması gerektiğidir.
    positions = []
    rank = 0
    for category in order:
        for t in sorted(t for t, (c, _) in templates.items() if c == category):
            rank += 1
            if AUDIENCE.get(t) == "personal":
                positions.append(rank)
    if positions:
        half = sum(1 for p in positions if p <= n / 2)
        print(f"\nkişisel şablonların {half}/{len(positions)}'i vitrinin ilk yarısında "
              f"(ilk {n // 2} kart)")
        print(f"ilk kişisel şablon {positions[0]}. kartta, ortancası "
              f"{sorted(positions)[len(positions) // 2]}. kartta")


if __name__ == "__main__":
    main()
