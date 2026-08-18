"""SOSYAL / GEZİ / KUTLAMA batch'i — 15 şablon.

Günlük paylaşım alışkanlıklarına karşılık gelen düzenler: gün anlatımı,
liste/soru-cevap kartları, fotoğraf yığını, gezi rehberi ve özel gün kartları.
Her şablon farklı bir iskelet kullanır — arka arkaya gelen iki şablon aynı
görünmesin diye montaj/klasik, tipografi/tam kadraj, kart/kolaj dönüşümlü.
"""

from templatelib import *   # noqa: F403


# 1 — Günüm: dört sahnelik gün akışı, her sahnede saat etiketi.
def day_in_life():
    t = Template("day-in-life-01", tr="Günüm", en="Day in My Life",
                 category="social", track="chill-01",
                 palette=PALETTES["cream"], pro=False)

    moments = [
        ("morning", "06:40", "Güne erken başlıyorum", "An early start today",
         "warm", "up"),
        ("noon", "13:15", "Öğle molası, uzun kahve", "Lunch break, long coffee",
         "vivid", "down"),
        ("evening", "18:50", "Gün batımında yürüyüş", "A walk at sunset",
         "warm", "left"),
        ("night", "22:30", "Günün son sayfası", "The last page of the day",
         "cool", "right"),
    ]

    for i, (key, clock, tr, en, filt, direction) in enumerate(moments):
        last = i == len(moments) - 1
        s = t.scene(key, 2.0,
                    transition=None if last else "crossDissolve",
                    transition_duration=0.4)
        s.add(media(f"m{i}", i, filter=filt, intensity=0.45,
                    anims=[ken_burns(2.0, zoom=1.1, direction=direction)]))
        s.add(scrim(f"veil{i}"))
        s.add(shape(f"chip{i}", "surface", x=0.22, y=0.115, w=0.26, h=0.062,
                    radius=0.031, anims=[pop(1.08, 0.45)]))
        s.add(text(f"time{i}", f"time{i}", clock, clock, 0.028,
                   x=0.22, y=0.115, w=0.24, h=0.05, font="AvenirNext-Heavy",
                   role="textPrimary", start=0.15, anims=[fade_in(0.35)]))
        s.add(text(f"cap{i}", f"cap{i}", tr, en, 0.05,
                   y=0.845, w=0.84, h=0.12, font="AvenirNext-Bold",
                   role="surface", lines=2, start=0.3,
                   anims=[slide_in("up", 0.05, 0.5)]))
    return t


# 2 — 3 Şey: üstte foto, altta numaralı liste; her madde başka yönden girer.
def three_things():
    t = Template("three-things-01", tr="3 Şey", en="Three Things",
                 category="social", track="clean-01",
                 palette=PALETTES["slate"], pro=False, duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, y=0.26, h=0.52, filter="cool", intensity=0.4,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.1, direction="up")]))
    t.add(scrim("photo-veil", y=0.26, h=0.52))
    t.add(text("kicker", "kicker", "BU HAFTA", "THIS WEEK", 0.02,
               y=0.33, w=0.6, h=0.035, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.012,
               start=0.35, anims=[fade_in(0.5)]))
    t.add(text("title", "title", "3 ŞEY", "3 THINGS", 0.075,
               y=0.42, w=0.7, h=0.11, font="AvenirNext-Heavy", caps=True,
               tracking=0.006, start=0.2, anims=[pop(1.1, 0.5)]))

    items = [
        ("Sabah 20 dakika yürüyüş", "A 20-minute morning walk", "left"),
        ("Telefonu masada bırakmak", "Leaving the phone on the table", "right"),
        ("Akşam bir bölüm okumak", "Reading a chapter at night", "up"),
    ]
    for i, (tr, en, direction) in enumerate(items):
        y = 0.62 + i * 0.115
        t.add(shape(f"dot{i}", "accent", x=0.155, y=y, w=0.10, h=0.056,
                    mask="circle", start=0.5 + 0.2 * i,
                    anims=[scale_in(0.7, 0.45)]))
        t.add(text(f"num{i}", f"num{i}", str(i + 1), str(i + 1), 0.03,
                   x=0.155, y=y, w=0.09, h=0.05, font="AvenirNext-Heavy",
                   role="background", start=0.6 + 0.2 * i,
                   anims=[fade_in(0.35)]))
        t.add(text(f"item{i}", f"item{i}", tr, en, 0.036,
                   x=0.585, y=y, w=0.65, h=0.085, font="AvenirNext-Medium",
                   align="left", lines=2, start=0.6 + 0.2 * i,
                   anims=[slide_in(direction, 0.06, 0.5)]))

    t.add(text("cta", "cta", "Seninkiler ne?", "What are yours?", 0.021,
               y=0.94, w=0.7, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.25, anims=[fade_in(0.6)]))
    return t


# 3 — Soru-Cevap: üstte balon, altta renkli cevap kartı, arkada silik foto.
def qa_card():
    t = Template("qa-card-01", tr="Soru-Cevap", en="Q&A",
                 category="social", track="smooth-01",
                 palette=PALETTES["grape"], pro=False, duration=7.0)
    t.add(bg())
    t.add(media("backdrop", 0, filter="fade", intensity=0.9,
                anims=[fade_in(0.5), ken_burns(7.0, zoom=1.15, direction="down")]))
    t.add(scrim("veil", direction="up"))

    t.add(shape("bubble", "surface", y=0.34, w=0.82, h=0.24, radius=0.06,
                anims=[scale_in(0.9, 0.55)]))
    t.add(shape("tail", "surface", x=0.30, y=0.47, w=0.06, h=0.034,
                rotation=45, anims=[scale_in(0.6, 0.4, delay=0.2)]))
    t.add(text("q-label", "qLabel", "SORU", "QUESTION", 0.02,
               y=0.255, w=0.5, h=0.035, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.012,
               start=0.35, anims=[fade_in(0.4)]))
    t.add(text("question", "question", "En çok sorulan:\nNasıl başladın?",
               "Most asked:\nHow did you start?", 0.042,
               y=0.355, w=0.72, h=0.13, font="AvenirNext-Bold",
               role="background", lines=3, start=0.45,
               anims=[slide_in("up", 0.03, 0.5)]))

    t.add(shape("answer", "accent", y=0.66, w=0.82, h=0.26, radius=0.06,
                start=0.6, anims=[slide_in("up", 0.06, 0.55)]))
    t.add(text("a-label", "aLabel", "CEVAP", "ANSWER", 0.02,
               y=0.575, w=0.5, h=0.035, font="AvenirNext-DemiBold",
               role="textOnAccent", caps=True, tracking=0.012,
               start=0.85, anims=[fade_in(0.4)]))
    t.add(text("answer-text", "answerText", "Küçük bir telefonla\nve çok merakla.",
               "With a small phone\nand a lot of curiosity.", 0.038,
               y=0.68, w=0.72, h=0.14, font="AvenirNext-Medium",
               role="textOnAccent", lines=3, start=0.95,
               anims=[typewriter(1.2)]))
    t.add(text("invite", "invite", "Sorularınızı bekliyorum", "Send me your questions",
               0.021, y=0.88, w=0.72, h=0.04, font="AvenirNext-Regular",
               role="textPrimary", start=1.3, anims=[fade_in(0.6)]))
    return t


# 4 — Bu mu Şu mu: dikey ikiye bölünmüş oylama kartı, ortada "VEYA" dairesi.
def poll_card():
    t = Template("poll-card-01", tr="Bu mu Şu mu", en="This or That",
                 category="social", track="punchy-01",
                 palette=PALETTES["punch"], pro=True, duration=6.0)
    t.add(bg())
    t.add(media("top", 0, y=0.25, h=0.5, kind="photo", filter="vivid",
                intensity=0.5,
                anims=[ken_burns(6.0, zoom=1.1, direction="down")]))
    t.add(media("bottom", 1, y=0.75, h=0.5, kind="photo", filter="vivid",
                intensity=0.5,
                anims=[ken_burns(6.0, zoom=1.1, direction="up")]))
    t.add(scrim("top-veil", direction="up", y=0.25, h=0.5))
    t.add(scrim("bottom-veil", direction="down", y=0.75, h=0.5))

    t.add(text("title", "title", "BU MU, ŞU MU?", "THIS OR THAT?", 0.052,
               y=0.10, w=0.86, h=0.09, font="AvenirNext-Heavy", caps=True,
               tracking=0.006, start=0.2, anims=[pop(1.1, 0.5)]))
    t.add(text("opt-a", "optA", "SAHİL", "BEACH", 0.046,
               y=0.32, w=0.6, h=0.08, font="AvenirNext-Bold", caps=True,
               tracking=0.014, start=0.5, anims=[slide_in("right", 0.07, 0.5)]))
    t.add(shape("or-circle", "accent", y=0.5, w=0.22, h=0.124, mask="circle",
                start=0.35, anims=[bounce(0.7)]))
    t.add(text("or", "or", "VEYA", "OR", 0.03,
               y=0.5, w=0.2, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, start=0.55, anims=[fade_in(0.35)]))
    t.add(text("opt-b", "optB", "DAĞ", "MOUNTAIN", 0.046,
               y=0.68, w=0.6, h=0.08, font="AvenirNext-Bold", caps=True,
               tracking=0.014, start=0.7, anims=[slide_in("left", 0.07, 0.5)]))
    t.add(text("cta", "cta", "Oyunu yoruma yaz", "Vote in the comments", 0.022,
               y=0.92, w=0.74, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.0, anims=[fade_in(0.5)]))
    return t


# 5 — Fotoğraf Yığını: tek sahnede eğik duran dört polaroid.
def photo_dump():
    """Polaroid yığını.

    KLASİK (v1) yolda kalır, montaj DEĞİL: her fotoğrafın ARKASINDA beyaz bir
    kart var ve montaj hattında shape'ler medyanın üstüne çizildiği için
    kartlar fotoğrafları örtüyordu. v1 katman sırasını olduğu gibi korur ve
    foto slotu sayısını sınırlamaz (sınır yalnız video slotunda: en fazla 1).
    """
    t = Template("photo-dump-01", tr="Fotoğraf Yığını", en="Photo Dump",
                 category="social", track="playful-01",
                 palette=PALETTES["paper"], pro=False, duration=6.0)
    t.add(bg())

    cards = [(0.30, 0.36, -7), (0.71, 0.32, 6), (0.31, 0.63, 5), (0.70, 0.67, -6)]
    for i, (x, y, rot) in enumerate(cards):
        t.add(shape(f"card{i}", "surface", x=x, y=y, w=0.42, h=0.30,
                    radius=0.008, rotation=rot,
                    start=0.1 * i, anims=[pop(1.06, 0.5)]))
        t.add(media(f"shot{i}", i, x=x, y=y - 0.017, w=0.375, h=0.245,
                    kind="photo", rotation=rot, filter="warm", intensity=0.3,
                    start=0.1 * i,
                    anims=[fade_in(0.4), ken_burns(6.0 - 0.1 * i, zoom=1.07,
                                                   direction="up")]))

    t.add(text("dump-kicker", "dumpKicker", "AĞUSTOS 2025", "AUGUST 2025", 0.02,
               y=0.045, w=0.6, h=0.03, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.014,
               start=0.2, anims=[fade_in(0.5)]))
    t.add(text("dump-title", "dumpTitle", "Fotoğraf yığını", "Photo dump", 0.055,
               y=0.11, w=0.8, h=0.09, font="Archivo-SemiBold",
               role="textPrimary", start=0.35, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(text("dump-foot", "dumpFoot", "Silmeye kıyamadıklarım",
               "The ones I couldn't delete", 0.022,
               y=0.90, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.0, anims=[fade_in(0.6)]))
    return t


# 6 — Haftalık Özet: kapak tipografisi → ikili kolaj → kapanış.
def weekly_recap():
    t = Template("weekly-recap-01", tr="Haftalık Özet", en="Weekly Recap",
                 category="social", track="cinematic-01",
                 palette=PALETTES["midnight"], pro=False)

    cover = t.scene("cover", 2.2, transition="slideUp", transition_duration=0.4)
    cover.add(bg("background", "cov-bg"))
    cover.add(shape("cov-glow", "accent", y=0.44, w=0.86, h=0.48, radius=0.24,
                    opacity=0.16, anims=[scale_in(0.85, 0.8), pulse(2.2, 1.04)]))
    cover.add(text("cov-kicker", "covKicker", "5 – 11 AĞUSTOS", "AUG 5 – 11", 0.022,
                   y=0.33, w=0.7, h=0.04, font="AvenirNext-DemiBold",
                   role="textSecondary", caps=True, tracking=0.014,
                   start=0.2, anims=[fade_in(0.5)]))
    cover.add(text("cov-title", "covTitle", "HAFTALIK\nÖZET", "WEEKLY\nRECAP", 0.078,
                   y=0.46, w=0.86, h=0.20, font="AvenirNext-Heavy",
                   lines=2, caps=True, start=0.35,
                   anims=[slide_in("up", 0.05, 0.6)]))
    cover.add(text("cov-sub", "covSub", "Üç güzel şey oldu", "Three good things happened",
                   0.024, y=0.60, w=0.78, h=0.045, font="AvenirNext-Regular",
                   role="textSecondary", start=0.8, anims=[fade_in(0.6)]))

    grid = t.scene("grid", 2.8, transition="blurDissolve", transition_duration=0.4)
    for i, x in enumerate((0.2525, 0.7475)):
        grid.add(media(f"g{i}", i, x=x, y=0.42, w=0.47, h=0.5, radius=0.012,
                       filter="cinematic", intensity=0.5,
                       anims=[scale_in(0.9, 0.5, delay=0.1 * i),
                              ken_burns(2.8, zoom=1.08, direction="up")]))
    grid.add(shape("g-rule", "accent", y=0.72, w=0.10, h=0.005,
                   start=0.5, anims=[wipe("right", 0.5)]))
    grid.add(text("g-title", "gTitle", "İki şehir, bir hafta", "Two cities, one week",
                  0.046, y=0.79, w=0.82, h=0.09, font="AvenirNext-Bold",
                  start=0.6, anims=[slide_in("up", 0.04, 0.55)]))
    grid.add(text("g-note", "gNote", "İzmir ve Ankara", "Denver and Austin", 0.022,
                  y=0.87, w=0.7, h=0.04, font="AvenirNext-Regular",
                  role="textSecondary", start=0.9, anims=[fade_in(0.5)]))

    close = t.scene("close", 2.0)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    close.add(shape("cl-ring", "accent", y=0.36, w=0.48, h=0.27, mask="circle",
                    opacity=0.28, anims=[scale_in(0.8, 0.7)]))
    close.add(media("cl-media", 2, y=0.36, w=0.44, h=0.2475, mask="circle",
                    filter="cinematic", intensity=0.4,
                    anims=[scale_in(0.85, 0.6), ken_burns(2.0, zoom=1.1,
                                                          direction="up")]))
    close.add(text("cl-title", "clTitle", "Haftaya görüşürüz", "See you next week",
                   0.046, y=0.58, w=0.82, h=0.09, font="AvenirNext-Bold",
                   start=0.3, anims=[slide_in("up", 0.04, 0.5)]))
    close.add(text("cl-handle", "clHandle", "@gunlukhikaye", "@dailystory", 0.021,
                   y=0.665, w=0.6, h=0.04, font="AvenirNext-Regular",
                   role="textSecondary", start=0.6, anims=[fade_in(0.5)]))
    return t


# 7 — Minik Dostum: tam kadraj + emoji çıkartmalar + isim/yaş satırı.
def pet_star():
    t = Template("pet-star-01", tr="Minik Dostum", en="Pet Star",
                 category="social", track="bright-01",
                 palette=PALETTES["citrus"], pro=False, duration=6.5)
    t.add(bg())
    t.add(media("pet", 0, filter="vivid", intensity=0.5,
                anims=[fade_in(0.5), ken_burns(6.5, zoom=1.12, direction="up")]))
    t.add(scrim("pet-veil"))

    t.add(shape("pet-badge", "accent", y=0.115, w=0.46, h=0.062, radius=0.031,
                start=0.2, anims=[pop(1.08, 0.5)]))
    t.add(text("pet-badge-text", "petBadge", "GÜNÜN YILDIZI", "STAR OF THE DAY",
               0.026, y=0.115, w=0.44, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.008,
               start=0.3, anims=[fade_in(0.4)]))

    t.add(sticker("paw", "paw", "🐾", 0.085, x=0.16, y=0.20, rotation=-12,
                  start=0.35, anims=[pop(1.12, 0.5)]))
    t.add(sticker("heart", "heart", "💛", 0.08, x=0.85, y=0.28, rotation=10,
                  start=0.55, anims=[bounce(0.6)]))
    t.add(sticker("star", "star", "⭐", 0.075, x=0.80, y=0.60, rotation=-8,
                  start=0.75, anims=[pop(1.15, 0.45)]))

    t.add(text("pet-name", "petName", "Pamuk", "Cookie", 0.072,
               y=0.795, w=0.8, h=0.12, font="AvenirNext-Heavy",
               start=0.5, anims=[slide_in("up", 0.05, 0.55)]))
    t.add(text("pet-info", "petInfo", "3 yaşında • Van kedisi", "3 years old • Van cat",
               0.023, y=0.88, w=0.76, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=0.85, anims=[fade_in(0.6)]))
    return t


# 8 — Geçen Yıl: vintage kare + tarih damgası + film şeridi kenarları.
def throwback():
    t = Template("throwback-01", tr="Geçen Yıl", en="Throwback",
                 category="social", track="dreamy-01",
                 palette=PALETTES["retro"], pro=True, duration=6.5)
    t.add(bg())
    t.add(media("tb", 0, filter="vintage", intensity=0.85,
                anims=[fade_in(0.6), ken_burns(6.5, zoom=1.08, direction="down")]))
    t.add(scrim("tb-top", direction="up", y=0.16, h=0.32))
    t.add(scrim("tb-bottom", y=0.80, h=0.40))

    t.add(shape("strip-l", "background", x=0.035, w=0.07, h=1.0, opacity=0.9))
    t.add(shape("strip-r", "background", x=0.965, w=0.07, h=1.0, opacity=0.9))
    for i, y in enumerate((0.12, 0.29, 0.46, 0.63, 0.80, 0.94)):
        t.add(shape(f"perf-l{i}", "surface", x=0.035, y=y, w=0.036, h=0.02,
                    radius=0.006, opacity=0.85))
        t.add(shape(f"perf-r{i}", "surface", x=0.965, y=y, w=0.036, h=0.02,
                    radius=0.006, opacity=0.85))

    t.add(text("tb-date", "tbDate", "12 · 08 · 2024", "12 · 08 · 2024", 0.032,
               y=0.105, w=0.6, h=0.055, font="Courier-Bold", role="accent",
               tracking=0.008, start=0.3, anims=[typewriter(1.2)]))
    t.add(text("tb-kicker", "tbKicker", "GEÇEN YIL BUGÜN", "ONE YEAR AGO TODAY", 0.021,
               y=0.165, w=0.7, h=0.035, font="AvenirNext-DemiBold",
               caps=True, tracking=0.012, start=0.8, anims=[fade_in(0.6)]))
    t.add(text("tb-caption", "tbCaption", "Aynı sahil,\naynı kahkaha",
               "Same shore,\nsame laughter", 0.044,
               y=0.845, w=0.78, h=0.14, font="Georgia-Italic", lines=2,
               start=1.0, anims=[slide_in("up", 0.04, 0.6)]))
    return t


# 9 — Şehir Rehberi: üç durak, her sahnede numaralı etiket; üstte kalıcı başlık.
def city_guide():
    t = Template("city-guide-01", tr="Şehir Rehberi", en="City Guide",
                 category="travel", track="wanderlust-01",
                 palette=PALETTES["ocean"], pro=False)

    stops = [
        ("KAHVALTI", "BREAKFAST", "Van Kahvaltı Evi", "Corner Breakfast House",
         "Kadıköy • 08:30", "Riverside • 08:30", "up"),
        ("KAHVE", "COFFEE", "Fazıl Bey Kahvesi", "Maple Street Coffee",
         "Moda • 11:00", "Harbor Walk • 11:00", "left"),
        ("GÜN BATIMI", "SUNSET", "Moda Sahili", "Harbor Walk",
         "Kadıköy • 19:45", "Riverside • 19:45", "down"),
    ]

    for i, (ltr, len_, ptr, pen, ntr, nen, direction) in enumerate(stops):
        last = i == len(stops) - 1
        s = t.scene(f"stop{i}", 2.4,
                    transition=None if last else "slideLeft",
                    transition_duration=0.4)
        s.add(media(f"c{i}", i, filter="cool", intensity=0.35,
                    anims=[ken_burns(2.4, zoom=1.1, direction=direction)]))
        s.add(scrim(f"c{i}-veil"))
        s.add(shape(f"c{i}-chip", "accent", x=0.155, y=0.70, w=0.11, h=0.062,
                    radius=0.031, start=0.15, anims=[pop(1.1, 0.45)]))
        s.add(text(f"c{i}-num", f"num{i}", str(i + 1), str(i + 1), 0.03,
                   x=0.155, y=0.70, w=0.10, h=0.05, font="AvenirNext-Heavy",
                   role="textOnAccent", start=0.25, anims=[fade_in(0.35)]))
        s.add(text(f"c{i}-label", f"label{i}", ltr, len_, 0.024,
                   x=0.56, y=0.70, w=0.62, h=0.045, font="AvenirNext-DemiBold",
                   role="accent", align="left", caps=True, tracking=0.014,
                   start=0.3, anims=[slide_in("left", 0.05, 0.45)]))
        s.add(text(f"c{i}-place", f"place{i}", ptr, pen, 0.052,
                   y=0.795, w=0.84, h=0.10, font="AvenirNext-Bold",
                   align="left", start=0.45, anims=[slide_in("up", 0.04, 0.5)]))
        s.add(text(f"c{i}-note", f"note{i}", ntr, nen, 0.022,
                   y=0.875, w=0.8, h=0.04, font="AvenirNext-Regular",
                   role="textSecondary", align="left",
                   start=0.65, anims=[fade_in(0.5)]))

    t.add(scrim("guide-veil", direction="up", y=0.10, h=0.20))
    t.add(text("guide-title", "guideTitle", "İSTANBUL REHBERİ", "CITY GUIDE",
               0.028, y=0.075, w=0.8, h=0.05, font="AvenirNext-DemiBold",
               caps=True, tracking=0.016, start=0.3, anims=[fade_in(0.6)]))
    return t


# 10 — Valiz Listesi: medyasız saf tipografi, tik işaretli beş madde.
def travel_checklist():
    t = Template("travel-checklist-01", tr="Valiz Listesi", en="Packing List",
                 category="travel", track="typewriter-01",
                 palette=PALETTES["forest"], pro=True, duration=8.0)
    t.add(bg())
    t.add(shape("sheet", "surface", y=0.52, w=0.86, h=0.68, radius=0.03,
                opacity=0.07, anims=[scale_in(0.94, 0.7)]))
    t.add(text("pl-title", "plTitle", "VALİZ LİSTESİ", "PACKING LIST", 0.062,
               y=0.215, w=0.86, h=0.09, font="AvenirNext-Heavy", caps=True,
               tracking=0.008, start=0.2, anims=[typewriter(1.3)]))
    t.add(text("pl-sub", "plSub", "3 günlük şehir kaçamağı", "A 3-day city escape",
               0.023, y=0.29, w=0.78, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.45, anims=[fade_in(0.6)]))

    items = [
        ("Fotoğraf makinesi + yedek pil", "Camera and a spare battery"),
        ("Üç tişört, iki pantolon", "Three tees, two pants"),
        ("Güneş kremi ve şapka", "Sunscreen and a hat"),
        ("Şarj aleti ve powerbank", "Charger and a power bank"),
        ("Pasaport ve kart", "Passport and cards"),
    ]
    for i, (tr, en) in enumerate(items):
        y = 0.40 + i * 0.09
        start = 0.6 + 0.2 * i
        t.add(text(f"tick{i}", f"tick{i}", "✓", "✓", 0.028,
                   x=0.20, y=y, w=0.062, h=0.045, font="AvenirNext-Heavy",
                   role="accent", start=start, anims=[pop(1.2, 0.4)]))
        t.add(text(f"pl-item{i}", f"item{i}", tr, en, 0.027,
                   x=0.60, y=y, w=0.60, h=0.06, font="AvenirNext-Medium",
                   align="left", start=start, anims=[slide_in("left", 0.05, 0.45)]))

    t.add(text("pl-foot", "plFoot", "Sen ne eklerdin?", "What would you add?", 0.022,
               y=0.87, w=0.74, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.7, anims=[fade_in(0.6)]))
    return t


# 11 — Gün Batımı: sıcak gradient + serif italik alıntı + konum satırı.
def sunset_diary():
    t = Template("sunset-diary-01", tr="Gün Batımı", en="Sunset Diary",
                 category="travel", track="ambient-01",
                 palette=PALETTES["sunset"], pro=False, duration=7.0)
    t.color("sunGlow", "#FF7A4500")
    t.color("sunDeep", "#2A0E1AF2")
    t.add(bg())
    t.add(media("sun", 0, filter="warm", intensity=0.55,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.12, direction="down")]))
    t.add(scrim("sun-top", direction="up", y=0.09, h=0.18))
    t.add(scrim("sun-veil", frm="sunGlow", to="sunDeep", y=0.72, h=0.56))

    t.add(text("sun-time", "sunTime", "19:42", "19:42", 0.026,
               y=0.08, w=0.4, h=0.045, font="AvenirNext-DemiBold",
               tracking=0.01, start=0.2, anims=[fade_in(0.5)]))
    t.add(text("sun-quote", "sunQuote", "Gün batımını\nizlemek de\nbir plandır.",
               "Watching the sun\ngo down counts\nas a plan.", 0.052,
               y=0.70, w=0.80, h=0.22, font="Georgia-Italic", lines=3,
               start=0.4, anims=[slide_in("up", 0.04, 0.7)]))
    t.add(shape("sun-dash", "accent", y=0.845, w=0.08, h=0.005,
                start=1.0, anims=[wipe("right", 0.5)]))
    t.add(text("sun-place", "sunPlace", "ÖLÜDENİZ, FETHİYE", "AMALFI, ITALY", 0.022,
               y=0.895, w=0.72, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.014,
               start=1.15, anims=[fade_in(0.6)]))
    return t


# 12 — Yol Hikâyesi: üç durak, whip ve slideLeft geçişler, km etiketleri.
def road_trip():
    t = Template("road-trip-01", tr="Yol Hikâyesi", en="Road Trip",
                 category="travel", track="energetic-01",
                 palette=PALETTES["sand"], pro=True)

    legs = [
        ("start", 2.3, "whip", 0.3, "KM 0 • İZMİR", "MILE 0 • DENVER",
         "Yola çıkıyoruz", "Hitting the road", "left"),
        ("road", 2.4, "slideLeft", 0.4, "KM 148 • ÇEŞME YOLU", "KM 148 • COAST ROAD",
         "Cam açık, müzik açık", "Windows down, music up", "up"),
        ("arrive", 2.3, None, 0.0, "KM 260 • ALAÇATI", "KM 260 • ALACATI",
         "Geldik sayılır", "Almost there", "right"),
    ]

    for i, (sid, dur, trans, tdur, ttr, ten, ctr, cen, direction) in enumerate(legs):
        s = t.scene(sid, dur, transition=trans, transition_duration=tdur)
        s.add(media(f"r{i}", i, filter="warm", intensity=0.4,
                    anims=[ken_burns(dur, zoom=1.12, direction=direction)]))
        s.add(scrim(f"r{i}-veil"))
        s.add(shape(f"r{i}-chip", "accent", x=0.32, y=0.79, w=0.48, h=0.062,
                    radius=0.031, start=0.15,
                    anims=[slide_in("left", 0.08, 0.45)]))
        s.add(text(f"r{i}-tag", f"tag{i}", ttr, ten, 0.024,
                   x=0.32, y=0.79, w=0.46, h=0.05, font="AvenirNext-Heavy",
                   role="textOnAccent", caps=True, tracking=0.008,
                   start=0.25, anims=[fade_in(0.35)]))
        s.add(text(f"r{i}-cap", f"cap{i}", ctr, cen, 0.05,
                   y=0.88, w=0.84, h=0.10, font="AvenirNext-Bold",
                   role="surface", start=0.4, anims=[slide_in("up", 0.05, 0.5)]))
    return t


# 13 — Yeni Yıl: koyu zemin, dev yıl rakamı, dilek cümlesi, parıltılar.
def new_year():
    t = Template("new-year-01", tr="Yeni Yıl", en="New Year",
                 category="holiday", track="impact-01",
                 palette=PALETTES["charcoal"], pro=False, duration=6.0)
    t.add(bg())
    t.add(shape("ny-glow", "accent", y=0.44, w=0.82, h=0.4613, mask="circle",
                opacity=0.16, anims=[scale_in(0.8, 0.9), pulse(2.6, 1.05)]))
    t.add(text("ny-kicker", "nyKicker", "MUTLU YILLAR", "HAPPY NEW YEAR", 0.024,
               y=0.30, w=0.8, h=0.045, font="AvenirNext-DemiBold",
               caps=True, tracking=0.018, start=0.2, anims=[fade_in(0.6)]))
    t.add(text("ny-year", "nyYear", "2026", "2026", 0.155,
               y=0.45, w=0.9, h=0.20, font="AvenirNext-Heavy",
               role="accent", tracking=0.004, start=0.35, anims=[pop(1.12, 0.6)]))
    t.add(text("ny-wish", "nyWish", "Yeni yıl, yeni\nhikâyeler getirsin.",
               "May the new year\nbring new stories.", 0.038,
               y=0.635, w=0.82, h=0.13, font="Georgia-Bold", lines=2,
               start=0.7, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("ny-sign", "nySign", "— Sevgiyle", "— With love", 0.022,
               y=0.755, w=0.6, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.05, anims=[fade_in(0.6)]))

    sparks = [("sp0", 0.17, 0.20, 0.07, -10, 0.45),
              ("sp1", 0.84, 0.22, 0.065, 12, 0.6),
              ("sp2", 0.16, 0.845, 0.06, 8, 0.9),
              ("sp3", 0.84, 0.865, 0.055, -14, 1.05)]
    for sid, x, y, size, rot, start in sparks:
        t.add(sticker(sid, sid, "✨", size, x=x, y=y, rotation=rot,
                      start=start, anims=[pop(1.15, 0.45)]))
    return t


# 14 — Doğum Günü: daire maskeli foto, çevresinde renkli noktalar, yaş rozeti.
def birthday_wish():
    t = Template("birthday-wish-01", tr="Doğum Günü", en="Birthday Wish",
                 category="holiday", track="sweet-01",
                 palette=PALETTES["rose"], pro=False, duration=7.0)
    t.color("dotA", "#FFD166")
    t.color("dotB", "#6C8CFF")
    t.color("dotC", "#7BE0A5")
    t.add(bg())
    t.add(shape("ring", "accent", y=0.40, w=0.55, h=0.309, mask="circle",
                opacity=0.35, anims=[scale_in(0.8, 0.7)]))
    t.add(media("face", 0, y=0.40, w=0.52, h=0.292, mask="circle",
                filter="warm", intensity=0.35,
                anims=[scale_in(0.88, 0.6), ken_burns(7.0, zoom=1.1,
                                                      direction="up")]))

    dots = [(0.80, 0.400, "dotA"), (0.65, 0.255, "accent"),
            (0.35, 0.255, "dotB"), (0.20, 0.400, "dotC"),
            (0.35, 0.545, "dotA"), (0.65, 0.545, "dotB")]
    for i, (x, y, role) in enumerate(dots):
        t.add(shape(f"dot{i}", role, x=x, y=y, w=0.05, h=0.028, mask="circle",
                    start=0.4 + 0.08 * i, anims=[pop(1.3, 0.4)]))

    t.add(shape("age-badge", "accent", x=0.80, y=0.53, w=0.16, h=0.09,
                mask="circle", start=0.9, anims=[bounce(0.6)]))
    t.add(text("age", "age", "25", "25", 0.034,
               x=0.80, y=0.53, w=0.14, h=0.06, font="AvenirNext-Heavy",
               role="textOnAccent", start=1.05, anims=[fade_in(0.4)]))

    t.add(text("bd-kicker", "bdKicker", "BUGÜN ÖZEL BİR GÜN", "TODAY IS A SPECIAL DAY",
               0.022, y=0.11, w=0.7, h=0.04, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.014,
               start=0.2, anims=[fade_in(0.6)]))
    t.add(text("bd-title", "bdTitle", "İYİ Kİ DOĞDUN", "HAPPY BIRTHDAY", 0.058,
               y=0.635, w=0.86, h=0.10, font="AvenirNext-Heavy", caps=True,
               tracking=0.006, start=0.6, anims=[pop(1.1, 0.55)]))
    t.add(text("bd-wish", "bdWish", "Nice mutlu yıllara Elif!", "Many happy returns, Mia!",
               0.024, y=0.75, w=0.76, h=0.045, font="AvenirNext-Medium",
               role="textSecondary", start=0.85, anims=[slide_in("up", 0.03, 0.5)]))

    t.add(sticker("confetti", "confetti", "🎉", 0.075, x=0.14, y=0.22,
                  rotation=-14, start=0.3, anims=[bounce(0.65)]))
    t.add(sticker("balloon", "balloon", "🎈", 0.07, x=0.86, y=0.20,
                  rotation=10, start=0.45, anims=[pop(1.15, 0.5)]))
    t.add(sticker("cake", "cake", "🎂", 0.075, x=0.5, y=0.86,
                  start=1.2, anims=[pop(1.2, 0.5)]))
    return t


# 15 — Anneler Günü: kalp maskeli foto + el yazısı mesaj, yumuşak pembe palet.
def mothers_day():
    t = Template("mothers-day-01", tr="Anneler Günü", en="Mother's Day",
                 category="holiday", track="warm-01",
                 palette=PALETTES["blush"], pro=True, duration=7.0)
    t.add(bg())
    t.add(shape("md-blob", "accent", y=0.32, w=0.92, h=0.52, radius=0.26,
                opacity=0.16, anims=[scale_in(0.9, 0.8), pulse(3.0, 1.03)]))
    t.add(media("md-photo", 0, y=0.33, w=0.62, h=0.42, mask="heart",
                filter="warm", intensity=0.4,
                anims=[scale_in(0.88, 0.7), ken_burns(7.0, zoom=1.08,
                                                      direction="up")]))
    t.add(text("md-kicker", "mdKicker", "ANNELER GÜNÜ", "MOTHER'S DAY", 0.022,
               y=0.075, w=0.7, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.016,
               start=0.25, anims=[fade_in(0.6)]))
    t.add(text("md-title", "mdTitle", "Canım annem", "Dearest mom", 0.078,
               y=0.63, w=0.84, h=0.13, font="SnellRoundhand-Bold",
               role="textPrimary", start=0.5, anims=[wipe("right", 0.9)]))
    t.add(text("md-msg", "mdMsg", "Her şey için teşekkür ederim.\nİyi ki varsın.",
               "Thank you for everything.\nI'm so glad you're here.", 0.026,
               y=0.755, w=0.76, h=0.09, font="AvenirNext-Regular",
               role="textSecondary", lines=2, start=0.9,
               anims=[slide_in("up", 0.03, 0.6)]))
    t.add(text("md-foot", "mdFoot", "Seni çok seviyorum", "I love you so much", 0.022,
               y=0.85, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="accent", start=1.2, anims=[fade_in(0.6)]))
    t.add(sticker("md-flower", "mdFlower", "🌸", 0.07, x=0.13, y=0.15,
                  rotation=-12, start=0.35, anims=[pop(1.15, 0.5)]))
    t.add(sticker("md-tulip", "mdTulip", "🌷", 0.065, x=0.88, y=0.20,
                  rotation=12, start=0.55, anims=[bounce(0.6)]))
    t.add(sticker("md-heart", "mdHeart", "❤️", 0.06, x=0.5, y=0.925,
                  start=1.4, anims=[pop(1.2, 0.45)]))
    return t


TEMPLATES = [
    day_in_life, three_things, qa_card, poll_card, photo_dump,
    weekly_recap, pet_star, throwback, city_guide, travel_checklist,
    sunset_diary, road_trip, new_year, birthday_wish, mothers_day,
]
