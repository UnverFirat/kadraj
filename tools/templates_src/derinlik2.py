"""DERİNLİK 2 BATCH — güzellik, spor ve moda kategorilerini derinleştirir.

Katalogda bu üç aile zaten dörder şablonla temsil ediliyordu (salon randevu,
öncesi/sonrası, tırnak, spa · gym kampanya, antrenman, koşu, değişim ·
lookbook, ızgara, deneme kabini, indirim). Buradaki 12 şablon o dördün
YANINA gelir: hiçbiri mevcut iskeleti tekrar etmez.

Yeni düzenler:
  renk şeridi · fiyat listesi kartı · numaralı bakım rutini · ürün noktalı
  portre · saat rozetli program · dev rekor rakamı · medyasız meydan okuma ·
  makro sütunları · numaralı stil ipucu · üçlü dikey şerit montajı ·
  kart içinde ürün detayı · "tükendi → yeniden stokta" iki sahneli montaj

Her şablon farklı palet kullanır (12 şablon, 12 palet).
"""

from templatelib import *   # noqa: F403


# ---------------------------------------------------------------- beauty

# 1 — Tam kadraj + altta dört renk kutusundan oluşan yatay kartela şeridi.
def hair_color():
    t = Template("hair-color-01", tr="Saç Rengi", en="Hair Colour",
                 category="beauty", track="smooth-01",
                 palette=PALETTES["rose"], duration=6.5)
    t.color("tone1", "#3B2A22")
    t.color("tone2", "#8A5A32")
    t.color("tone3", "#C08A4E")
    t.color("tone4", "#E3C89A")
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.35,
                anims=[fade_in(0.6), ken_burns(6.5, zoom=1.11, direction="up")]))
    t.add(scrim("scrim", y=0.72, h=0.56))
    t.add(text("kicker", "kicker", "SEZONUN TONLARI", "THIS SEASON'S SHADES", 0.022,
               y=0.635, w=0.8, h=0.038, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.016,
               start=0.3, anims=[fade_in(0.55)]))
    t.add(text("headline", "headline", "Yeni ton, yeni sen", "New shade, new you", 0.052,
               y=0.70, w=0.86, h=0.075, font="AvenirNext-Bold",
               start=0.45, anims=[slide_in("up", 0.035, 0.55)]))

    swatches = [
        ("tone1", 0.1925), ("tone2", 0.3975),
        ("tone3", 0.6025), ("tone4", 0.8075),
    ]
    for i, (role, x) in enumerate(swatches):
        t.add(shape(f"swatch{i}", role, x=x, y=0.79, w=0.17, h=0.09,
                    radius=0.012, start=0.7 + 0.12 * i,
                    anims=[pop(1.12, 0.4)]))
    t.add(shape("pick", "accent", x=0.6025, y=0.848, w=0.17, h=0.006,
                radius=0.003, start=1.15, anims=[wipe("right", 0.45)]))
    t.add(text("tone-name", "toneName", "Bal Köpüğü", "Honey Foam", 0.048,
               y=0.888, w=0.82, h=0.07, font="Georgia-Bold",
               start=1.2, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("note", "note", "3 seansta ulaşılır · Renk danışmanlığı ücretsiz",
               "Reached in three sessions · Free colour consult", 0.02,
               y=0.95, w=0.9, h=0.032, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 2 — Üstte foto şeridi, altta zemin kartı: dört hizmet satırı + ince ayraçlar.
def price_list():
    t = Template("price-list-01", tr="Hizmet Fiyatları", en="Price List",
                 category="beauty", track="ambient-01",
                 palette=PALETTES["ivory"], pro=True, duration=7.5)
    t.add(bg())
    t.add(media("photo", 0, y=0.155, h=0.31, filter="fade", intensity=0.3,
                anims=[fade_in(0.6), ken_burns(7.5, zoom=1.08, direction="down")]))
    t.add(scrim("scrim", direction="up", y=0.155, h=0.31))
    t.add(text("salon", "salon", "GÜZELLİK ATÖLYESİ", "THE BEAUTY ROOM", 0.03,
               y=0.115, w=0.86, h=0.05, font="Didot",
               role="surface", caps=True, tracking=0.02,
               start=0.3, anims=[fade_in(0.6)]))
    t.add(text("kicker", "kicker", "FİYAT LİSTESİ · 2026", "PRICE LIST · 2026", 0.019,
               y=0.185, w=0.8, h=0.032, font="AvenirNext-Medium",
               role="surface", caps=True, tracking=0.014,
               start=0.45, anims=[fade_in(0.55)]))
    t.add(shape("card", "surface", y=0.635, w=0.9, h=0.60, radius=0.03,
                start=0.35, anims=[slide_in("up", 0.05, 0.6)]))

    rows = [
        ("Fön + Bakım", "Blow-dry + Treatment", "45 dakika", "45 min", "₺450", "$38"),
        ("Kesim & Şekillendirme", "Cut & Style", "60 dakika", "60 min", "₺650", "$55"),
        ("Dip Boya", "Root Colour", "90 dakika", "90 min", "₺1.200", "$95"),
        ("Keratin Bakımı", "Keratin Treatment", "120 dakika", "120 min",
         "₺2.400", "$180"),
    ]
    for i, (tr_name, en_name, tr_dur, en_dur, tr_price, en_price) in enumerate(rows):
        y = 0.42 + 0.125 * i
        begin = 0.55 + 0.15 * i
        t.add(text(f"name{i}", f"service{i + 1}", tr_name, en_name, 0.032,
                   x=0.31, y=y, w=0.44, h=0.05, font="AvenirNext-DemiBold",
                   align="left", start=begin,
                   anims=[slide_in("right", 0.035, 0.5)]))
        t.add(text(f"dur{i}", f"service{i + 1}Duration", tr_dur, en_dur, 0.018,
                   x=0.31, y=y + 0.042, w=0.44, h=0.03, font="AvenirNext-Regular",
                   role="textSecondary", align="left", start=begin + 0.05,
                   anims=[fade_in(0.45)]))
        t.add(text(f"price{i}", f"service{i + 1}Price", tr_price, en_price, 0.034,
                   x=0.79, y=y, w=0.28, h=0.05, font="AvenirNext-Heavy",
                   role="accent", align="right", start=begin + 0.08,
                   anims=[fade_in(0.45)]))
        if i < len(rows) - 1:
            t.add(shape(f"rule{i}", "textSecondary", y=y + 0.0675, w=0.78,
                        h=0.0015, opacity=0.3, start=begin + 0.12,
                        anims=[wipe("right", 0.5)]))

    t.add(text("book", "book", "Randevu · 0532 000 00 00", "Book · 555 010 0134", 0.022,
               y=0.885, w=0.8, h=0.04, font="AvenirNext-Heavy",
               role="accent", tracking=0.006, start=1.15,
               anims=[pop(1.05, 0.45)]))
    t.add(text("small", "small", "Fiyatlar saç boyuna göre değişebilir",
               "Prices may vary with hair length", 0.018,
               y=0.94, w=0.86, h=0.03, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 3 — Üstte foto, altta numaralı üç adımlık sabah rutini.
def skincare_steps():
    t = Template("skincare-steps-01", tr="Bakım Rutini", en="Skincare Routine",
                 category="beauty", track="calm-01",
                 palette=PALETTES["cream"], duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, y=0.235, h=0.47, filter="warm", intensity=0.3,
                anims=[fade_in(0.7), ken_burns(7.0, zoom=1.09, direction="down")]))
    t.add(scrim("scrim", direction="up", y=0.11, h=0.22))
    t.add(text("kicker", "kicker", "SABAH RUTİNİ", "MORNING ROUTINE", 0.022,
               y=0.09, w=0.8, h=0.038, font="AvenirNext-DemiBold",
               role="surface", caps=True, tracking=0.016,
               start=0.3, anims=[fade_in(0.6)]))
    t.add(text("title", "title", "3 adımda parlak cilt", "Glowing skin in 3 steps",
               0.05, y=0.545, w=0.88, h=0.075, font="Georgia-Bold",
               start=0.5, anims=[slide_in("up", 0.03, 0.6)]))

    steps = [
        ("01", "Nazik temizleyici", "Gentle cleanser",
         "Ilık suyla 30 saniye", "Thirty seconds, lukewarm water"),
        ("02", "C vitamini serum", "Vitamin C serum",
         "3–4 damla, nemli cilde", "Three drops on damp skin"),
        ("03", "SPF 50 güneş kremi", "SPF 50 sunscreen",
         "Her sabah, bulutlu bile olsa", "Every morning, even when cloudy"),
    ]
    for i, (num, tr_name, en_name, tr_note, en_note) in enumerate(steps):
        y = 0.645 + 0.11 * i
        begin = 0.7 + 0.16 * i
        t.add(text(f"num{i}", f"step{i + 1}Num", num, num, 0.042,
                   x=0.13, y=y, w=0.14, h=0.07, font="AvenirNext-Heavy",
                   role="accent", start=begin, anims=[pop(1.12, 0.45)]))
        t.add(text(f"step{i}", f"step{i + 1}", tr_name, en_name, 0.032,
                   x=0.585, y=y - 0.021, w=0.66, h=0.05,
                   font="AvenirNext-DemiBold", align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.04, 0.5)]))
        t.add(text(f"note{i}", f"step{i + 1}Note", tr_note, en_note, 0.019,
                   x=0.585, y=y + 0.027, w=0.66, h=0.034,
                   font="AvenirNext-Regular", role="textSecondary", align="left",
                   start=begin + 0.1, anims=[fade_in(0.5)]))
        if i < len(steps) - 1:
            t.add(shape(f"line{i}", "textSecondary", y=y + 0.0575, w=0.78,
                        h=0.0015, opacity=0.3, start=begin + 0.15,
                        anims=[wipe("right", 0.5)]))

    t.add(text("footer", "footer", "Akşam rutini yarın · Kaydet",
               "Evening routine tomorrow · Save this", 0.02,
               y=0.955, w=0.86, h=0.03, font="AvenirNext-Medium",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 4 — Ortada daire portre, çevresinde numaralı ürün noktaları, altta görünüm adı.
def makeup_look():
    t = Template("makeup-look-01", tr="Makyaj Görünümü", en="Makeup Look",
                 category="beauty", track="sweet-01",
                 palette=PALETTES["blush"], pro=True, duration=7.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.42, w=0.92, h=0.5175, mask="circle",
                opacity=0.14, anims=[scale_in(0.85, 0.9), pulse(3.0, 1.03)]))
    t.add(text("kicker", "kicker", "MAKYAJ GÖRÜNÜMÜ", "MAKEUP LOOK", 0.022,
               y=0.10, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.018,
               start=0.25, anims=[slide_in("down", 0.035, 0.5)]))
    t.add(shape("ring", "accent", y=0.42, w=0.585, h=0.329, mask="circle",
                anims=[scale_in(0.88, 0.7)]))
    t.add(media("portrait", 0, y=0.42, w=0.56, h=0.315, mask="circle",
                filter="warm", intensity=0.3,
                anims=[scale_in(0.9, 0.7),
                       ken_burns(7.0, zoom=1.08, direction="up")]))

    dots = [
        (0.115, 0.315, "1", "Ten fondöten", "Skin tint"),
        (0.885, 0.315, "2", "Bronzer paleti", "Bronzer palette"),
        (0.115, 0.545, "3", "Işıltı likidi", "Liquid highlighter"),
        (0.885, 0.545, "4", "Nude ruj", "Nude lipstick"),
    ]
    for i, (x, y, num, tr_label, en_label) in enumerate(dots):
        begin = 0.75 + 0.12 * i
        t.add(shape(f"dot{i}", "surface", x=x, y=y, w=0.085, h=0.0478,
                    mask="circle", start=begin, anims=[pop(1.15, 0.4)]))
        t.add(text(f"dotnum{i}", f"product{i + 1}Num", num, num, 0.024,
                   x=x, y=y, w=0.07, h=0.04, font="AvenirNext-Heavy",
                   role="textPrimary", start=begin + 0.05, anims=[fade_in(0.35)]))
        t.add(text(f"dotlabel{i}", f"product{i + 1}", tr_label, en_label, 0.018,
                   x=x, y=y + 0.052, w=0.21, h=0.05, font="AvenirNext-Medium",
                   role="textSecondary", lines=2, start=begin + 0.1,
                   anims=[fade_in(0.5)]))

    t.add(text("look-name", "lookName", "Bronz Işıltı", "Bronze Glow", 0.058,
               y=0.745, w=0.8, h=0.09, font="Didot",
               start=1.15, anims=[slide_in("up", 0.035, 0.6)]))
    t.add(shape("rule", "accent", y=0.805, w=0.10, h=0.004,
                start=1.2, anims=[wipe("right", 0.5)]))
    t.add(text("sub", "sub", "Günlük makyaj · 10 dakika", "Everyday look · 10 minutes",
               0.022, y=0.855, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    t.add(text("cta", "cta", "Ürün listesi için DM at", "DM me for the product list",
               0.021, y=0.925, w=0.84, h=0.038, font="AvenirNext-DemiBold",
               role="accent", start=1.2, anims=[fade_in(0.65)]))
    return t


# --------------------------------------------------------------- fitness

# 5 — Karartılmış tam kadraj + saat rozetli dört ders satırı.
def class_schedule():
    t = Template("class-schedule-01", tr="Ders Programı", en="Class Schedule",
                 category="fitness", track="beat-01",
                 palette=PALETTES["midnight"], duration=7.5)
    t.add(bg())
    t.add(media("photo", 0, filter="cool", intensity=0.4,
                anims=[fade_in(0.5), ken_burns(7.5, zoom=1.10, direction="left")]))
    t.add(shape("veil", "background", opacity=0.68, anims=[fade_in(0.7)]))
    t.add(scrim("scrim", direction="up", y=0.16, h=0.32))
    t.add(text("kicker", "kicker", "HAFTALIK PROGRAM", "WEEKLY SCHEDULE", 0.022,
               y=0.10, w=0.8, h=0.038, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.018,
               start=0.25, anims=[fade_in(0.55)]))
    t.add(text("title", "title", "Ders Saatleri", "Class Timetable", 0.058,
               y=0.175, w=0.88, h=0.09, font="AvenirNext-Heavy",
               start=0.4, anims=[slide_in("down", 0.04, 0.55)]))
    t.add(shape("rule", "accent", y=0.245, w=0.12, h=0.005,
                start=0.6, anims=[wipe("right", 0.55)]))

    classes = [
        ("07.00", "Sabah HIIT", "Morning HIIT", "Deniz ile", "with Deniz"),
        ("12.30", "Öğle Pilates", "Lunch Pilates", "Ece ile", "with Ece"),
        ("18.00", "Fonksiyonel Güç", "Functional Strength", "Kaan ile", "with Kaan"),
        ("20.00", "Akşam Yogası", "Evening Yoga", "Sude ile", "with Sude"),
    ]
    for i, (hour, tr_name, en_name, tr_coach, en_coach) in enumerate(classes):
        y = 0.365 + 0.14 * i
        begin = 0.7 + 0.16 * i
        t.add(shape(f"chip{i}", "accent", x=0.205, y=y, w=0.30, h=0.08,
                    radius=0.04, start=begin, anims=[pop(1.08, 0.45)]))
        t.add(text(f"hour{i}", f"class{i + 1}Time", hour, hour, 0.03,
                   x=0.205, y=y, w=0.27, h=0.05, font="Archivo-SemiBold",
                   role="background", start=begin + 0.05, anims=[fade_in(0.35)]))
        t.add(text(f"class{i}", f"class{i + 1}", tr_name, en_name, 0.032,
                   x=0.665, y=y - 0.019, w=0.50, h=0.05,
                   font="AvenirNext-DemiBold", align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.04, 0.5)]))
        t.add(text(f"coach{i}", f"class{i + 1}Coach", tr_coach, en_coach, 0.019,
                   x=0.665, y=y + 0.028, w=0.50, h=0.034,
                   font="AvenirNext-Regular", role="textSecondary", align="left",
                   start=begin + 0.1, anims=[fade_in(0.5)]))

    t.add(text("footer", "footer", "Yer ayırtmak için DM · İlk ders ücretsiz",
               "DM to reserve · First class free", 0.021,
               y=0.905, w=0.88, h=0.038, font="AvenirNext-Medium",
               role="accent", start=1.2, anims=[fade_in(0.65)]))
    return t


# 6 — Tam kadraj + ortada dev rekor rakamı, üstünde hareket, altında karşılaştırma.
def pr_card():
    t = Template("pr-card-01", tr="Yeni Rekor", en="New PR",
                 category="fitness", track="impact-01",
                 palette=PALETTES["charcoal"], pro=True, duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="cinematic", intensity=0.5,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.14, direction="up")]))
    t.add(shape("veil", "background", opacity=0.3, anims=[fade_in(0.6)]))
    t.add(scrim("scrim-top", direction="up", y=0.20, h=0.40))
    t.add(scrim("scrim-bottom", y=0.76, h=0.48))
    t.add(text("kicker", "kicker", "YENİ REKOR", "NEW PR", 0.026,
               y=0.105, w=0.8, h=0.042, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.022,
               start=0.25, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(text("movement", "movement", "BENCH PRESS", "BENCH PRESS", 0.034,
               y=0.345, w=0.86, h=0.055, font="AvenirNext-DemiBold",
               caps=True, tracking=0.016, start=0.45,
               anims=[fade_in(0.55)]))
    t.add(text("value", "value", "82,5", "182", 0.155,
               y=0.485, w=0.9, h=0.20, font="AvenirNext-Heavy",
               tracking=0.004, start=0.6, anims=[scale_in(0.82, 0.7)]))
    t.add(text("unit", "unit", "KİLOGRAM", "POUNDS", 0.022,
               y=0.625, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.024,
               start=0.9, anims=[fade_in(0.5)]))
    t.add(shape("rule", "accent", y=0.70, w=0.14, h=0.005,
                start=1.0, anims=[wipe("right", 0.55)]))
    t.add(text("previous", "previous", "Önceki rekor 77,5 kg", "Previous best 175 lb",
               0.026, y=0.775, w=0.86, h=0.045, font="AvenirNext-DemiBold",
               role="accent", start=1.05, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("date", "date", "9 Ağustos 2026 · 5. set", "August 9, 2026 · fifth set",
               0.021, y=0.845, w=0.86, h=0.038, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    t.add(text("handle", "handle", "@antrenman.gunlugu", "@liftlog", 0.019,
               y=0.915, w=0.7, h=0.034, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 7 — Medyasız: dev "30", altında üç kısa madde ve katılım çağrısı.
def challenge():
    t = Template("challenge-01", tr="30 Gün Meydan Okuma", en="30-Day Challenge",
                 category="fitness", track="punchy-01",
                 palette=PALETTES["electric"], duration=6.5)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.30, w=0.94, h=0.50, radius=0.25,
                opacity=0.13, anims=[scale_in(0.85, 1.0), pulse(2.6, 1.04)]))
    t.add(text("kicker", "kicker", "MEYDAN OKUMA", "THE CHALLENGE", 0.024,
               y=0.115, w=0.82, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.024,
               start=0.2, anims=[fade_in(0.55)]))
    t.add(text("big", "big", "30", "30", 0.17,
               y=0.29, w=0.9, h=0.22, font="AvenirNext-Heavy",
               start=0.35, anims=[scale_in(0.78, 0.7)]))
    t.add(text("word", "word", "GÜN", "DAYS", 0.05,
               y=0.445, w=0.8, h=0.075, font="Archivo-SemiBold",
               caps=True, tracking=0.05, start=0.6,
               anims=[slide_in("up", 0.03, 0.55)]))
    t.add(shape("rule", "accent", y=0.515, w=0.12, h=0.005,
                start=0.8, anims=[wipe("right", 0.55)]))

    bullets = [
        ("Her gün 20 şınav", "Twenty push-ups a day"),
        ("Haftada 3 koşu · 5 km", "Three 5K runs a week"),
        ("30 gün şeker yok", "Zero added sugar"),
    ]
    for i, (tr_line, en_line) in enumerate(bullets):
        y = 0.60 + 0.085 * i
        begin = 0.85 + 0.15 * i
        t.add(shape(f"mark{i}", "accent", x=0.145, y=y, w=0.028, h=0.0158,
                    mask="circle", start=begin, anims=[pop(1.2, 0.4)]))
        t.add(text(f"line{i}", f"rule{i + 1}", tr_line, en_line, 0.03,
                   x=0.585, y=y, w=0.68, h=0.05, font="AvenirNext-Medium",
                   align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.04, 0.5)]))

    t.add(shape("cta-chip", "accent", y=0.875, w=0.68, h=0.09, radius=0.045,
                start=1.2, anims=[pop(1.08, 0.5)]))
    t.add(text("cta", "cta", "1 EYLÜL'DE BAŞLIYOR", "STARTS SEPTEMBER 1", 0.03,
               y=0.875, w=0.64, h=0.055, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.008,
               start=1.2, anims=[fade_in(0.45)]))
    t.add(text("footer", "footer", "Katılmak için yoruma VARIM yaz",
               "Comment I'M IN to join", 0.02,
               y=0.955, w=0.86, h=0.032, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 8 — Üstte tabak fotosu, altta üç sütunlu makro dağılımı + oran çubukları.
def nutrition_tip():
    t = Template("nutrition-tip-01", tr="Beslenme İpucu", en="Nutrition Tip",
                 category="fitness", track="energetic-01",
                 palette=PALETTES["forest"], pro=True, duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, y=0.27, h=0.54, filter="vivid", intensity=0.35,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.10, direction="down")]))
    t.add(scrim("scrim", direction="up", y=0.11, h=0.22))
    t.add(text("kicker", "kicker", "BESLENME İPUCU", "NUTRITION TIP", 0.022,
               y=0.09, w=0.82, h=0.038, font="AvenirNext-DemiBold",
               caps=True, tracking=0.018, start=0.3, anims=[fade_in(0.55)]))
    t.add(text("title", "title", "Tabağını böyle kur", "Build your plate like this",
               0.052, y=0.625, w=0.88, h=0.08, font="AvenirNext-Bold",
               start=0.5, anims=[slide_in("up", 0.035, 0.6)]))
    t.add(text("sub", "sub", "Her ana öğünde üçünü de bulundur",
               "Hit all three at every main meal", 0.021,
               y=0.695, w=0.86, h=0.038, font="AvenirNext-Regular",
               role="textSecondary", start=0.7, anims=[fade_in(0.55)]))
    t.add(shape("rule", "textSecondary", y=0.745, w=0.86, h=0.0015, opacity=0.3,
                start=0.85, anims=[wipe("right", 0.6)]))

    macros = [
        (0.20, "PROTEİN", "PROTEIN", "%40", "40%", 0.22),
        (0.50, "KARBONHİDRAT", "CARBS", "%40", "40%", 0.22),
        (0.80, "YAĞ", "FAT", "%20", "20%", 0.11),
    ]
    for i, (x, tr_label, en_label, tr_value, en_value, bar_w) in enumerate(macros):
        begin = 0.95 + 0.12 * i
        t.add(text(f"label{i}", f"macro{i + 1}Label", tr_label, en_label, 0.018,
                   x=x, y=0.795, w=0.28, h=0.03, font="AvenirNext-Medium",
                   role="textSecondary", caps=True, tracking=0.012,
                   start=begin, anims=[fade_in(0.45)]))
        t.add(text(f"value{i}", f"macro{i + 1}", tr_value, en_value, 0.048,
                   x=x, y=0.858, w=0.28, h=0.075, font="Archivo-SemiBold",
                   start=begin + 0.05, anims=[slide_in("up", 0.025, 0.45)]))
        t.add(shape(f"bar{i}", "accent", x=x, y=0.912, w=bar_w, h=0.007,
                    radius=0.0035, start=begin + 0.1, anims=[wipe("right", 0.5)]))
    t.add(shape("div1", "textSecondary", x=0.35, y=0.845, w=0.0015, h=0.10,
                opacity=0.35, start=1.1, anims=[fade_in(0.4)]))
    t.add(shape("div2", "textSecondary", x=0.65, y=0.845, w=0.0015, h=0.10,
                opacity=0.35, start=1.2, anims=[fade_in(0.4)]))
    t.add(text("note", "note", "Örnek: tavuk + bulgur + avokado",
               "Example: chicken, bulgur, avocado", 0.02,
               y=0.955, w=0.9, h=0.032, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# --------------------------------------------------------------- fashion

# 9 — Tam kadraj kombin, sağ üstte numara rozeti, altta tek cümlelik ipucu.
def style_tip():
    t = Template("style-tip-01", tr="Stil İpucu", en="Style Tip",
                 category="fashion", track="chill-01",
                 palette=PALETTES["mono"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="vintage", intensity=0.25,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.10, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.14, h=0.28))
    t.add(scrim("scrim-bottom", y=0.76, h=0.48))
    t.add(shape("badge", "accent", x=0.855, y=0.115, w=0.15, h=0.0844,
                mask="circle", start=0.3, anims=[pop(1.15, 0.5)]))
    t.add(text("badge-num", "tipNumber", "04", "04", 0.032,
               x=0.855, y=0.115, w=0.13, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", start=0.45, anims=[fade_in(0.35)]))
    t.add(text("kicker", "kicker", "STİL İPUCU", "STYLE TIP", 0.024,
               x=0.30, y=0.115, w=0.44, h=0.04, font="AvenirNext-DemiBold",
               align="left", caps=True, tracking=0.02,
               start=0.5, anims=[wipe("right", 0.55)]))
    t.add(shape("rule", "accent", y=0.70, w=0.10, h=0.004,
                start=0.7, anims=[wipe("right", 0.5)]))
    t.add(text("tip", "tip", "Tek renk giyin,\ndokuyu değiştir.",
               "Wear one colour,\nchange the texture.", 0.052,
               y=0.80, w=0.86, h=0.15, font="Georgia-Italic", lines=2,
               start=0.8, anims=[slide_in("up", 0.04, 0.65)]))
    t.add(text("footer", "footer", "Kaydet · @gardirop.notlari",
               "Save this · @closetnotes", 0.02,
               y=0.935, w=0.8, h=0.034, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.006,
               start=1.15, anims=[fade_in(0.6)]))
    return t


# 10 — Montaj tek sahne: üç dikey şerit yan yana, üstte başlık, altta parça sayısı.
def capsule():
    t = Template("capsule-01", tr="Kapsül Gardırop", en="Capsule Wardrobe",
                 category="fashion", track="clean-01",
                 palette=PALETTES["paper"], pro=True)
    s = t.scene("capsule", 6.0)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    strips = [
        (0.168, "up", None, "ÜST", "TOPS"),
        (0.500, "down", "fade", "ALT", "BOTTOMS"),
        (0.832, "up", "mono", "DIŞ", "OUTERWEAR"),
    ]
    for i, (x, direction, filt, tr_label, en_label) in enumerate(strips):
        s.add(media(f"strip{i}", i, x=x, y=0.50, w=0.328, h=0.66, kind="photo",
                    radius=0.006, filter=filt,
                    intensity=0.35 if filt else None,
                    anims=[scale_in(0.92, 0.55, delay=0.12 * i),
                           ken_burns(6.0, zoom=1.07, direction=direction)]))
        s.add(scrim(f"strip{i}-scrim", x=x, y=0.71, w=0.328, h=0.24))
        s.add(text(f"strip{i}-label", f"group{i + 1}", tr_label, en_label, 0.021,
                   x=x, y=0.775, w=0.30, h=0.04, font="AvenirNext-DemiBold",
                   role="surface", caps=True, tracking=0.014,
                   start=0.75 + 0.12 * i, anims=[fade_in(0.5)]))

    s.add(text("kicker", "kicker", "KAPSÜL GARDIROP", "CAPSULE WARDROBE", 0.022,
               y=0.065, w=0.86, h=0.032, font="AvenirNext-Medium",
               role="accent", caps=True, tracking=0.018,
               start=0.25, anims=[fade_in(0.55)]))
    s.add(text("title", "title", "Az parça, çok kombin", "Fewer pieces, more looks",
               0.05, y=0.125, w=0.88, h=0.075, font="Archivo-SemiBold",
               start=0.4, anims=[slide_in("down", 0.035, 0.55)]))
    s.add(text("count", "count", "12 PARÇA", "12 PIECES", 0.055,
               y=0.885, w=0.8, h=0.09, font="AvenirNext-Heavy",
               caps=True, tracking=0.012, start=1.1,
               anims=[slide_in("up", 0.035, 0.6)]))
    s.add(text("sub", "sub", "Sonbahar 26 · Hepsi birbiriyle uyumlu",
               "Fall 26 · Everything works together", 0.02,
               y=0.955, w=0.9, h=0.032, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 11 — Kart içinde yakın plan ürün fotosu + ad/fiyat satırı + malzeme notu.
def accessory():
    t = Template("accessory-01", tr="Aksesuar Detayı", en="Accessory Detail",
                 category="fashion", track="groovy-01",
                 palette=PALETTES["sand"], duration=6.5)
    t.add(bg())
    t.add(text("brand", "brand", "DERİ ATÖLYESİ", "LEATHER STUDIO", 0.022,
               y=0.085, w=0.8, h=0.038, font="AvenirNext-Medium",
               role="accent", caps=True, tracking=0.02,
               start=0.2, anims=[fade_in(0.55)]))
    t.add(shape("brand-rule", "accent", y=0.135, w=0.10, h=0.003,
                start=0.4, anims=[wipe("right", 0.5)]))
    t.add(shape("card", "surface", y=0.45, w=0.86, h=0.54, radius=0.02,
                start=0.35, anims=[scale_in(0.94, 0.6)]))
    t.add(media("photo", 0, y=0.425, w=0.74, h=0.42, radius=0.012,
                filter="warm", intensity=0.35,
                anims=[fade_in(0.6), ken_burns(6.5, zoom=1.09, direction="left")]))
    t.add(shape("badge", "accent", x=0.755, y=0.225, w=0.30, h=0.072,
                radius=0.036, rotation=-8, start=0.7, anims=[bounce(0.6)]))
    t.add(text("badge-text", "badge", "EL YAPIMI", "HANDMADE", 0.026,
               x=0.755, y=0.225, w=0.28, h=0.045, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.008, rotation=-8,
               start=0.85, anims=[fade_in(0.4)]))
    t.add(text("name", "name", "Deri Omuz Çantası", "Leather Shoulder Bag", 0.04,
               x=0.31, y=0.775, w=0.46, h=0.065, font="Georgia-Bold",
               align="left", start=0.95, anims=[slide_in("up", 0.03, 0.55)]))
    t.add(text("price", "price", "₺2.450", "$189", 0.042,
               x=0.79, y=0.775, w=0.28, h=0.065, font="AvenirNext-Heavy",
               role="accent", align="right", start=1.05,
               anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("material", "material", "Bitkisel sepi deri · Pirinç toka",
               "Veg-tanned leather · Brass buckle", 0.021,
               y=0.845, w=0.86, h=0.038, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    t.add(text("stock", "stock", "Sınırlı üretim · 20 adet", "Limited run · 20 made",
               0.02, y=0.90, w=0.8, h=0.034, font="AvenirNext-DemiBold",
               role="accent", start=1.2, anims=[fade_in(0.6)]))
    t.add(text("handle", "handle", "@deri.atolyesi", "@leatherstudio", 0.019,
               y=0.955, w=0.7, h=0.032, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 12 — Montaj: üstü çizili "TÜKENDİ" tipografisi → whip → "YENİDEN STOKTA".
def restock():
    t = Template("restock-01", tr="Yeniden Stokta", en="Back in Stock",
                 category="fashion", track="bright-01",
                 palette=PALETTES["punch"], pro=True)

    gone = t.scene("gone", 2.4, transition="whip", transition_duration=0.35)
    gone.add(bg("background", "gone-bg"))
    gone.add(text("gone-kicker", "goneKicker", "GEÇEN HAFTA", "LAST WEEK", 0.024,
                  y=0.36, w=0.8, h=0.04, font="AvenirNext-Medium",
                  role="textSecondary", caps=True, tracking=0.022,
                  start=0.2, anims=[fade_in(0.5)]))
    gone.add(text("gone-word", "goneWord", "TÜKENDİ", "SOLD OUT", 0.095,
                  y=0.47, w=0.9, h=0.15, font="AvenirNext-Heavy",
                  caps=True, tracking=0.006, start=0.35,
                  anims=[pop(1.08, 0.55)]))
    gone.add(shape("gone-strike", "accent", y=0.47, w=0.74, h=0.014,
                   start=0.85, anims=[wipe("right", 0.45)]))
    gone.add(text("gone-note", "goneNote", "Bekleme listesi bir günde doldu",
                  "The waitlist filled in a day", 0.022,
                  y=0.60, w=0.84, h=0.04, font="AvenirNext-Regular",
                  role="textSecondary", start=1.05, anims=[fade_in(0.5)]))

    back = t.scene("back", 3.6)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    back.add(media("back-media", 0, filter="vivid", intensity=0.4,
                   anims=[ken_burns(3.6, zoom=1.12, direction="up")]))
    back.add(scrim("back-scrim-top", direction="up", y=0.20, h=0.40))
    back.add(scrim("back-scrim", y=0.78, h=0.44))
    back.add(shape("back-chip", "accent", y=0.145, w=0.66, h=0.095, radius=0.0475,
                   start=0.2, anims=[pop(1.12, 0.5)]))
    back.add(text("back-label", "backLabel", "YENİDEN STOKTA", "BACK IN STOCK", 0.032,
                  y=0.145, w=0.62, h=0.055, font="AvenirNext-Heavy",
                  role="textOnAccent", caps=True, tracking=0.01,
                  start=0.35, anims=[fade_in(0.4)]))
    back.add(text("back-name", "backName", "Keten Gömlek", "Linen Shirt", 0.054,
                  y=0.79, w=0.86, h=0.085, font="AvenirNext-Heavy",
                  start=0.5, anims=[slide_in("up", 0.05, 0.55)]))
    back.add(text("back-price", "backPrice", "₺349", "$29", 0.036,
                  y=0.868, w=0.6, h=0.055, font="AvenirNext-Bold",
                  role="accent", start=0.75, anims=[pop(1.06, 0.45)]))
    back.add(text("back-cta", "backCta", "Sınırlı sayıda · Profildeki bağlantı",
                  "Limited stock · Link in bio", 0.021,
                  y=0.935, w=0.88, h=0.038, font="AvenirNext-Medium",
                  role="textSecondary", start=0.95, anims=[fade_in(0.55)]))
    return t


TEMPLATES = [
    hair_color, price_list, skincare_steps, makeup_look,
    class_schedule, pr_card, challenge, nutrition_tip,
    style_tip, capsule, accessory, restock,
]
