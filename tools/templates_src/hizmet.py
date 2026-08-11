"""HİZMET BATCH — küçük işletmelerin hizmet duyuruları.

Güzellik salonu, spor salonu, emlak, eğitim ve işe alım: hepsi "bir hizmeti
tanıt, iletişime geçir" işini yapar. Bu yüzden her şablon somut bir bilgi
taşıyor (telefon, tarih, fiyat, adres) — kullanıcı hiçbir alanı düzenlemeden
paylaşsa bile ortada anlamlı bir duyuru kalıyor.

Düzenler bilinçli olarak birbirinden ayrık: tam kadraj + kart, iki sahneli
öncesi/sonrası, daire kolajı, dergi sayfası, eğik rozet, numaralı liste,
istatistik kartı, üç sahneli hikâye yayı, şerit + adres bloğu, künye
sütunları, köşe rozeti, daire portre, saf tipografi, bilet paneli.
"""

from templatelib import *   # noqa: F403


# ---------------------------------------------------------------- beauty

# 1 — Tam kadraj foto + altta yuvarlak köşeli randevu kartı.
def salon_booking():
    t = Template("salon-booking-01", tr="Kuaför Randevu", en="Salon Booking",
                 category="beauty", track="calm-01",
                 palette=PALETTES["blush"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.4,
                anims=[fade_in(0.7), ken_burns(6.5, zoom=1.11, direction="up")]))
    t.add(scrim())
    t.add(shape("card", "surface", y=0.79, w=0.86, h=0.32, radius=0.042,
                start=0.35, anims=[slide_in("up", 0.06, 0.6)]))
    t.add(text("salon", "salon", "GÜZELLİK SALONU", "HAIR STUDIO", 0.02,
               y=0.675, w=0.7, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.01,
               start=0.6, anims=[fade_in(0.5)]))
    t.add(text("service", "service", "Kesim, Boya & Fön", "Cut, Colour & Blowout", 0.05,
               y=0.735, w=0.78, h=0.075, font="AvenirNext-Bold",
               role="textPrimary", start=0.75,
               anims=[slide_in("up", 0.03, 0.55)]))
    t.add(shape("rule", "accent", y=0.788, w=0.11, h=0.004,
                start=0.95, anims=[wipe("right", 0.5)]))
    t.add(text("book", "book", "Randevu için DM gönder", "Send a DM to book", 0.024,
               y=0.835, w=0.74, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.0, anims=[fade_in(0.6)]))
    t.add(text("phone", "phone", "0532 000 00 00", "555 010 0134", 0.032,
               y=0.895, w=0.7, h=0.05, font="AvenirNext-Heavy",
               role="accent", tracking=0.006, start=1.15,
               anims=[pop(1.06, 0.45)]))
    return t


# 2 — Montaj: iki sahne, "ÖNCE" → whip → "SONRA".
def beauty_before_after():
    t = Template("beauty-before-after-01", tr="Öncesi & Sonrası",
                 en="Before & After", category="beauty", track="smooth-01",
                 palette=PALETTES["rose"], pro=True)

    a = t.scene("before", 3.4, transition="whip", transition_duration=0.4)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş).
    a.add(media("a-media", 0, filter="fade", intensity=0.35,
                anims=[ken_burns(3.4, zoom=1.1, direction="up")]))
    a.add(scrim("a-scrim", direction="up"))
    a.add(shape("a-pill", "surface", y=0.135, w=0.36, h=0.088, radius=0.044,
                start=0.2, anims=[pop(1.1, 0.5)]))
    a.add(text("a-label", "beforeLabel", "ÖNCE", "BEFORE", 0.034,
               y=0.135, w=0.34, h=0.055, font="AvenirNext-Heavy",
               role="background", caps=True, tracking=0.012,
               start=0.35, anims=[fade_in(0.4)]))
    a.add(text("a-note", "beforeNote", "Yıpranmış uçlar", "Dry, tired ends", 0.024,
               y=0.225, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=0.6, anims=[fade_in(0.5)]))

    b = t.scene("after", 3.4)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    b.add(media("b-media", 1, filter="vivid", intensity=0.45,
                anims=[ken_burns(3.4, zoom=1.1, direction="down")]))
    b.add(scrim("b-scrim", direction="up"))
    b.add(scrim("b-scrim-bottom"))
    b.add(shape("b-pill", "accent", y=0.135, w=0.36, h=0.088, radius=0.044,
                start=0.2, anims=[pop(1.12, 0.5)]))
    b.add(text("b-label", "afterLabel", "SONRA", "AFTER", 0.034,
               y=0.135, w=0.34, h=0.055, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.012,
               start=0.35, anims=[scale_in(0.8, 0.4)]))
    b.add(text("b-head", "afterHead", "Tek seansta\nbalyaj", "One session,\nfull balayage", 0.05,
               y=0.83, w=0.84, h=0.15, font="AvenirNext-Bold", lines=2,
               start=0.5, anims=[slide_in("up", 0.05, 0.55)]))
    b.add(text("b-cta", "afterCta", "Sıra sende · DM at", "Your turn — DM us", 0.026,
               y=0.925, w=0.78, h=0.045, font="AvenirNext-Medium",
               role="accent", start=0.85, anims=[fade_in(0.5)]))
    return t


# 3 — Üç daire maskeli fotoğraf, zikzak yerleşim. Metin fotoğrafın dışında.
def nail_art():
    t = Template("nail-art-01", tr="Tırnak Sanatı", en="Nail Art",
                 category="beauty", track="playful-01",
                 palette=PALETTES["grape"], pro=True, duration=7.0)
    t.add(bg())
    t.add(text("title", "title", "TIRNAK SANATI", "NAIL ART EDIT", 0.056,
               y=0.135, w=0.88, h=0.09, font="AvenirNext-Heavy",
               caps=True, tracking=0.008, start=0.2,
               anims=[slide_in("down", 0.04, 0.55)]))
    t.add(text("sub", "sub", "Bu haftanın üç favorisi", "Three sets we loved this week", 0.022,
               y=0.215, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.45, anims=[fade_in(0.5)]))

    spots = [(0.29, 0.36), (0.71, 0.50), (0.29, 0.66)]
    for i, (x, y) in enumerate(spots):
        t.add(media(f"nail{i}", i, x=x, y=y, w=0.40, h=0.225, kind="photo",
                    mask="circle", filter="vivid", intensity=0.4,
                    anims=[scale_in(0.86, 0.55, delay=0.15 * i),
                           ken_burns(7.0, zoom=1.08, direction="up")]))

    t.add(sticker("spark", "spark", "💅", size=0.07, x=0.80, y=0.735,
                  rotation=-10, start=1.1, anims=[pop(1.15, 0.5)]))
    t.add(text("ask", "ask", "Sence hangisi?", "Which one is yours?", 0.034,
               y=0.81, w=0.84, h=0.06, font="AvenirNext-Bold",
               start=1.15, anims=[slide_in("up", 0.04, 0.5)]))
    t.add(text("cta", "cta", "Randevu · 0532 000 00 00", "Book · 555 010 0134", 0.028,
               y=0.885, w=0.84, h=0.05, font="AvenirNext-DemiBold",
               role="accent", tracking=0.005, start=1.2,
               anims=[fade_in(0.55)]))
    return t


# 4 — Dergi sayfası: üstte geniş foto, ince çizgi, serif başlık.
def spa_calm():
    t = Template("spa-calm-01", tr="Bakım Daveti", en="Spa Invite",
                 category="beauty", track="ambient-01",
                 palette=PALETTES["ivory"], duration=6.5)
    t.add(bg("surface"))
    t.add(media("photo", 0, y=0.30, h=0.56, filter="fade", intensity=0.4,
                anims=[fade_in(0.9), ken_burns(6.5, zoom=1.07, direction="down")]))
    t.add(shape("rule", "accent", y=0.655, w=0.09, h=0.0035,
                start=0.6, anims=[wipe("right", 0.6)]))
    t.add(text("kicker", "kicker", "HUZUR MOLASI", "A QUIET HOUR", 0.019,
               y=0.70, w=0.72, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.012,
               start=0.7, anims=[fade_in(0.6)]))
    t.add(text("title", "title", "Kendine bir\nsaat ayır", "Give yourself\nan hour off", 0.058,
               y=0.805, w=0.8, h=0.16, font="Didot", lines=2,
               start=0.9, anims=[slide_in("up", 0.03, 0.75)]))
    t.add(text("sub", "sub", "Cilt bakımı & masaj · Cumartesi 10.00", "Facials & massage · Saturdays from 10", 0.021,
               y=0.925, w=0.82, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# ---------------------------------------------------------------- fitness

# 5 — Tam kadraj + eğik rozet + kalın kampanya başlığı.
def gym_offer():
    t = Template("gym-offer-01", tr="Spor Salonu Kampanya", en="Gym Offer",
                 category="fitness", track="energetic-01",
                 palette=PALETTES["punch"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="cinematic", intensity=0.5,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.14, direction="up")]))
    t.add(scrim())
    t.add(shape("badge", "accent", x=0.71, y=0.24, w=0.46, h=0.115, radius=0.057,
                rotation=-9, start=0.45, anims=[bounce(0.65)]))
    t.add(text("badge-text", "badge", "İLK AY\nÜCRETSİZ", "FIRST MONTH\nFREE", 0.032,
               x=0.71, y=0.24, w=0.42, h=0.095, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, lines=2, rotation=-9,
               start=0.6, anims=[fade_in(0.35)]))
    t.add(text("headline", "headline", "GÜCÜNÜ\nKEŞFET", "TRAIN\nHARDER", 0.08,
               y=0.755, w=0.86, h=0.19, font="AvenirNext-Heavy",
               caps=True, lines=2, start=0.75,
               anims=[slide_in("up", 0.05, 0.6)]))
    t.add(text("terms", "terms", "Yeni üyelere özel · 31 Ağustos'a kadar",
               "New members only · through Aug 31", 0.022,
               y=0.885, w=0.84, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.05, anims=[fade_in(0.6)]))
    t.add(text("handle", "handle", "@spor.salonu", "@yourgym", 0.02,
               y=0.94, w=0.6, h=0.035, font="AvenirNext-DemiBold",
               role="accent", start=1.2, anims=[fade_in(0.5)]))
    return t


# 6 — Üstte medya, altta numaralı üç satır; her satır kademeli girer.
def workout_steps():
    t = Template("workout-steps-01", tr="Antrenman Programı", en="Workout Plan",
                 category="fitness", track="punchy-01",
                 palette=PALETTES["electric"], pro=True, duration=7.5)
    t.add(bg())
    t.add(media("photo", 0, y=0.245, h=0.49, filter="mono", intensity=0.4,
                anims=[fade_in(0.5), ken_burns(7.5, zoom=1.1, direction="up")]))
    t.add(scrim("scrim", y=0.35, h=0.28))
    t.add(text("title", "title", "BUGÜNÜN ANTRENMANI", "TODAY'S SESSION", 0.034,
               y=0.565, w=0.88, h=0.05, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.01, start=0.35,
               anims=[wipe("right", 0.6)]))

    rows = [
        ("1", "Isınma · 5 dakika", "Warm-up · 5 min"),
        ("2", "Squat · 4 × 12", "Squats · 4 × 12"),
        ("3", "Plank · 3 × 45 sn", "Plank · 3 × 45 sec"),
    ]
    for i, (num, tr_text, en_text) in enumerate(rows):
        y = 0.665 + 0.11 * i
        begin = 0.6 + 0.25 * i
        t.add(shape(f"dot{i}", "accent", x=0.17, y=y, w=0.13, h=0.0731,
                    mask="circle", start=begin, anims=[pop(1.12, 0.45)]))
        t.add(text(f"num{i}", f"step{i + 1}Num", num, num, 0.03,
                   x=0.17, y=y, w=0.10, h=0.05, font="AvenirNext-Heavy",
                   role="textOnAccent", start=begin + 0.05,
                   anims=[fade_in(0.3)]))
        t.add(text(f"move{i}", f"step{i + 1}", tr_text, en_text, 0.036,
                   x=0.585, y=y, w=0.62, h=0.075, font="AvenirNext-DemiBold",
                   align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.05, 0.5)]))
    return t


# 7 — Koşu kartı: ortada büyük mesafe, altında iki küçük istatistik.
def run_stats():
    t = Template("run-stats-01", tr="Koşu Kartı", en="Run Stats",
                 category="fitness", track="beat-01",
                 palette=PALETTES["midnight"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="cool", intensity=0.45,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.12, direction="down")]))
    t.add(scrim("scrim-top", direction="up", y=0.28, h=0.56))
    t.add(scrim("scrim-bottom", y=0.72, h=0.56))
    t.add(text("kicker", "kicker", "SABAH KOŞUSU", "MORNING RUN", 0.024,
               y=0.115, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.014, start=0.25,
               anims=[fade_in(0.5)]))
    t.add(text("distance", "distance", "10,4", "6.5", 0.13,
               y=0.55, w=0.8, h=0.18, font="AvenirNext-Heavy",
               start=0.4, anims=[scale_in(0.82, 0.6)]))
    t.add(text("unit", "unit", "KİLOMETRE", "MILES", 0.022,
               y=0.665, w=0.6, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.02,
               start=0.7, anims=[fade_in(0.5)]))
    t.add(shape("divider", "textSecondary", y=0.825, w=0.003, h=0.09,
                opacity=0.5, start=0.9, anims=[fade_in(0.5)]))
    t.add(text("time-value", "timeValue", "52:10", "52:10", 0.042,
               x=0.30, y=0.80, w=0.34, h=0.065, font="AvenirNext-Bold",
               start=0.95, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("time-label", "timeLabel", "SÜRE", "TIME", 0.018,
               x=0.30, y=0.855, w=0.34, h=0.03, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.016,
               start=1.05, anims=[fade_in(0.45)]))
    t.add(text("pace-value", "paceValue", "5'01\"", "8'02\"", 0.042,
               x=0.70, y=0.80, w=0.34, h=0.065, font="AvenirNext-Bold",
               start=1.05, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("pace-label", "paceLabel", "TEMPO", "PACE", 0.018,
               x=0.70, y=0.855, w=0.34, h=0.03, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.016,
               start=1.15, anims=[fade_in(0.45)]))
    t.add(text("handle", "handle", "@kosuyorum", "@runlog", 0.019,
               y=0.93, w=0.6, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.5)]))
    return t


# 8 — Üç sahneli değişim hikâyesi, crossDissolve.
def transformation():
    t = Template("transformation-01", tr="Değişim Hikâyesi", en="Transformation",
                 category="fitness", track="impact-01",
                 palette=PALETTES["charcoal"], pro=True)

    one = t.scene("week-one", 2.6, transition="crossDissolve", transition_duration=0.5)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    one.add(media("one-media", 0, filter="mono", intensity=0.45,
                  anims=[ken_burns(2.6, zoom=1.12, direction="up")]))
    one.add(scrim("one-scrim", direction="up"))
    one.add(text("one-title", "weekOne", "1. HAFTA", "WEEK 1", 0.07,
                 y=0.16, w=0.86, h=0.11, font="AvenirNext-Heavy",
                 caps=True, tracking=0.01, start=0.2, anims=[pop(1.08, 0.5)]))
    one.add(text("one-note", "weekOneNote", "İlk gün, hiç antrenman yok",
                 "Day one, zero training", 0.024,
                 y=0.245, w=0.8, h=0.04, font="AvenirNext-Regular",
                 role="textSecondary", start=0.55, anims=[fade_in(0.5)]))

    eight = t.scene("week-eight", 2.6, transition="crossDissolve", transition_duration=0.5)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    eight.add(media("eight-media", 1, filter="vivid", intensity=0.4,
                    anims=[ken_burns(2.6, zoom=1.12, direction="down")]))
    eight.add(scrim("eight-scrim", direction="up"))
    eight.add(text("eight-title", "weekEight", "8. HAFTA", "WEEK 8", 0.07,
                   y=0.16, w=0.86, h=0.11, font="AvenirNext-Heavy",
                   role="accent", caps=True, tracking=0.01,
                   start=0.2, anims=[scale_in(0.85, 0.5)]))
    eight.add(text("eight-note", "weekEightNote", "Haftada üç gün, aksatmadan",
                   "Three days a week, no excuses", 0.024,
                   y=0.245, w=0.8, h=0.04, font="AvenirNext-Regular",
                   role="textSecondary", start=0.55, anims=[fade_in(0.5)]))

    end = t.scene("closing", 2.8)
    end.add(bg("background", "end-bg"))
    end.add(shape("end-mark", "accent", y=0.36, w=0.24, h=0.135, mask="circle",
                  anims=[scale_in(0.6, 0.6)]))
    end.add(sticker("end-spark", "spark", "🔥", size=0.07, y=0.36,
                    start=0.3, anims=[pop(1.2, 0.5)]))
    end.add(text("end-line", "closing", "Sen de bugün\nbaşlayabilirsin",
                 "Your week one\nstarts today", 0.058,
                 y=0.56, w=0.82, h=0.17, font="AvenirNext-Bold", lines=2,
                 start=0.5, anims=[slide_in("up", 0.04, 0.6)]))
    end.add(text("end-cta", "closingCta", "Ücretsiz deneme dersi · DM",
                 "Free trial session · DM us", 0.022,
                 y=0.70, w=0.8, h=0.04, font="AvenirNext-Medium",
                 role="textSecondary", start=0.95, anims=[fade_in(0.6)]))
    return t


# ------------------------------------------------------------- realestate

# 9 — Üstte tam genişlik şerit, altta tarih/saat/adres bloğu.
def open_house():
    t = Template("open-house-01", tr="Açık Ev", en="Open House",
                 category="realestate", track="clean-01",
                 palette=PALETTES["slate"], duration=6.5)
    t.color("ribbon", "#2F6DF6")
    t.add(bg())
    t.add(media("photo", 0, filter="cool", intensity=0.3,
                anims=[fade_in(0.6), ken_burns(6.5, zoom=1.1, direction="left")]))
    t.add(scrim("scrim-top", direction="up", y=0.16, h=0.32))
    t.add(scrim("scrim-bottom"))
    t.add(shape("ribbon-bar", "ribbon", y=0.115, w=1.0, h=0.088,
                start=0.2, anims=[wipe("right", 0.6)]))
    t.add(text("ribbon-text", "ribbon", "AÇIK EV · PAZAR", "OPEN HOUSE · SUNDAY", 0.03,
               y=0.115, w=0.9, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.012,
               start=0.5, anims=[fade_in(0.4)]))
    t.add(text("summary", "summary", "3+1 DAİRE · 120 m² · ASANSÖRLÜ",
               "3 BED · 1,290 FT² · ELEVATOR", 0.024,
               y=0.705, w=0.86, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.008,
               start=0.7, anims=[fade_in(0.5)]))
    t.add(text("date", "date", "12 Ekim Pazar", "Sunday, October 12", 0.04,
               y=0.78, w=0.86, h=0.065, font="AvenirNext-Bold",
               start=0.85, anims=[slide_in("up", 0.04, 0.55)]))
    t.add(text("hours", "hours", "14.00 – 17.00", "2 PM – 5 PM", 0.032,
               y=0.848, w=0.7, h=0.05, font="AvenirNext-DemiBold",
               role="accent", tracking=0.01, start=1.0,
               anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("address", "address", "Bahariye Cad. No:14, Kadıköy",
               "14 Maple Avenue, Riverside", 0.022,
               y=0.908, w=0.86, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 10 — Künye: üstte foto, altta üç sütun (alan / oda / kat).
def property_specs():
    t = Template("property-specs-01", tr="Daire Künyesi", en="Property Specs",
                 category="realestate", track="smooth-01",
                 palette=PALETTES["paper"], pro=True, duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, y=0.285, w=0.92, h=0.53, radius=0.012,
                filter="warm", intensity=0.25,
                anims=[fade_in(0.7), ken_burns(7.0, zoom=1.08, direction="up")]))
    t.add(text("title", "title", "Deniz Manzaralı Daire", "Sea-View Apartment", 0.05,
               y=0.625, w=0.86, h=0.08, font="Georgia-Bold",
               start=0.5, anims=[slide_in("up", 0.03, 0.6)]))
    t.add(text("sub", "sub", "Kiralık · Konak, İzmir", "For rent · Konak, İzmir", 0.022,
               y=0.695, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.7, anims=[fade_in(0.55)]))
    t.add(shape("rule", "accent", y=0.75, w=0.86, h=0.002, opacity=0.35,
                start=0.85, anims=[wipe("right", 0.7)]))

    cols = [
        (0.20, "ALAN", "AREA", "120 m²", "1,290 ft²"),
        (0.50, "ODA", "ROOMS", "3+1", "3 bed"),
        (0.80, "KAT", "FLOOR", "4 / 8", "4 of 8"),
    ]
    for i, (x, tr_label, en_label, tr_value, en_value) in enumerate(cols):
        begin = 0.95 + 0.15 * i
        t.add(text(f"label{i}", f"spec{i + 1}Label", tr_label, en_label, 0.018,
                   x=x, y=0.805, w=0.28, h=0.03, font="AvenirNext-Medium",
                   role="textSecondary", caps=True, tracking=0.016,
                   start=begin, anims=[fade_in(0.45)]))
        t.add(text(f"value{i}", f"spec{i + 1}", tr_value, en_value, 0.036,
                   x=x, y=0.862, w=0.28, h=0.07, font="AvenirNext-Heavy",
                   start=begin + 0.05, anims=[slide_in("up", 0.025, 0.45)]))
    t.add(shape("div1", "textSecondary", x=0.35, y=0.845, w=0.002, h=0.09,
                opacity=0.4, start=1.1, anims=[fade_in(0.4)]))
    t.add(shape("div2", "textSecondary", x=0.65, y=0.845, w=0.002, h=0.09,
                opacity=0.4, start=1.2, anims=[fade_in(0.4)]))
    t.add(text("cta", "cta", "Görmek için: 0532 000 00 00",
               "Viewings by appointment · 555 010 0134", 0.02,
               y=0.935, w=0.86, h=0.04, font="AvenirNext-DemiBold",
               role="accent", start=1.2, anims=[fade_in(0.6)]))
    return t


# 11 — Tam kadraj + köşede eğik fiyat rozeti + altta konum satırı.
def for_rent():
    t = Template("for-rent-01", tr="Kiralık İlan", en="For Rent",
                 category="realestate", track="bright-01",
                 palette=PALETTES["steel"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="cinematic", intensity=0.35,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.11, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.13, h=0.26))
    t.add(scrim("scrim-bottom"))
    t.add(shape("badge", "accent", x=0.735, y=0.155, w=0.44, h=0.10, radius=0.05,
                rotation=-6, start=0.4, anims=[pop(1.12, 0.5)]))
    t.add(text("price", "price", "₺18.500/ay", "$1,450/mo", 0.034,
               x=0.735, y=0.155, w=0.40, h=0.06, font="AvenirNext-Heavy",
               role="textOnAccent", rotation=-6, start=0.55,
               anims=[fade_in(0.4)]))
    t.add(text("headline", "headline", "KİRALIK DAİRE", "NOW FOR RENT", 0.052,
               y=0.755, w=0.86, h=0.08, font="AvenirNext-Heavy",
               caps=True, tracking=0.012, start=0.7,
               anims=[wipe("right", 0.7)]))
    t.add(text("info", "info", "Moda, Kadıköy · 2+1 · 95 m²",
               "Riverside · 2 bed · 1,020 ft²", 0.026,
               y=0.83, w=0.86, h=0.045, font="AvenirNext-DemiBold",
               role="accent", start=0.95, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("extra", "extra", "Eşyalı · Hemen taşınabilir · DM",
               "Furnished · Move-in ready · DM", 0.021,
               y=0.895, w=0.86, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# ------------------------------------------------------------- education

# 12 — Renkli zemin + ortada daire maskeli eğitmen portresi.
def course_promo():
    t = Template("course-promo-01", tr="Kurs Duyurusu", en="Course Promo",
                 category="education", track="bright-01",
                 palette=PALETTES["citrus"], duration=6.5)
    t.add(bg("accent"))
    t.add(shape("halo", "background", y=0.34, w=0.72, h=0.405, mask="circle",
                opacity=0.12, anims=[scale_in(0.85, 0.9), pulse(3.0, 1.03)]))
    t.add(text("kicker", "kicker", "YENİ DÖNEM", "NEW TERM", 0.024,
               y=0.10, w=0.8, h=0.04, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.018,
               start=0.2, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(media("photo", 0, y=0.34, w=0.58, h=0.32625, mask="circle",
                filter="vivid", intensity=0.3,
                anims=[scale_in(0.9, 0.7), ken_burns(6.5, zoom=1.08, direction="up")]))
    t.add(text("course", "course", "Sıfırdan İngilizce\nKonuşma Kursu",
               "English Speaking\nfrom Scratch", 0.058,
               y=0.635, w=0.84, h=0.17, font="AvenirNext-Heavy",
               role="textOnAccent", lines=2, start=0.6,
               anims=[slide_in("up", 0.04, 0.6)]))
    t.add(shape("panel", "background", y=0.815, w=0.72, h=0.115, radius=0.03,
                start=0.85, anims=[slide_in("up", 0.05, 0.55)]))
    t.add(text("start", "start", "8 Eylül'de başlıyor", "Starts September 8", 0.032,
               y=0.79, w=0.66, h=0.05, font="AvenirNext-Bold",
               start=1.0, anims=[fade_in(0.5)]))
    t.add(text("seats", "seats", "Kontenjan 12 kişi · Online", "12 seats · Live online", 0.02,
               y=0.845, w=0.66, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.1, anims=[fade_in(0.5)]))
    t.add(text("cta", "cta", "Kayıt: profildeki bağlantı", "Enrol via the link in bio", 0.021,
               y=0.925, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="textOnAccent", start=1.2, anims=[fade_in(0.6)]))
    return t


# 13 — Medyasız saf tipografi: başlık + numaralı üç madde.
def lesson_tips():
    t = Template("lesson-tips-01", tr="3 İpucu", en="3 Tips",
                 category="education", track="clean-01",
                 palette=PALETTES["neon"], pro=True, duration=7.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.30, w=0.9, h=0.5, radius=0.25,
                opacity=0.14, anims=[scale_in(0.85, 1.0), pulse(2.6, 1.04)]))
    t.add(text("title", "title", "3 İPUCU", "3 QUICK TIPS", 0.082,
               y=0.185, w=0.88, h=0.12, font="AvenirNext-Heavy",
               caps=True, tracking=0.01, start=0.2,
               anims=[typewriter(1.1)]))
    t.add(text("sub", "sub", "Daha az saatte daha çok öğren",
               "Study smarter, not longer", 0.023,
               y=0.272, w=0.82, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.45, anims=[fade_in(0.55)]))
    t.add(shape("rule", "accent", y=0.33, w=0.1, h=0.004,
                start=0.6, anims=[wipe("right", 0.5)]))

    tips = [
        ("01", "Her gün 20 dakika,\nhaftada bir 3 saat değil",
         "Twenty minutes daily\nbeats a three-hour cram"),
        ("02", "Not almadan önce\nkonuyu sesli anlat",
         "Say it out loud before\nyou write a single note"),
        ("03", "Telefonu başka odaya\nbırak — gerçekten.",
         "Leave the phone in\nanother room. Really."),
    ]
    for i, (num, tr_text, en_text) in enumerate(tips):
        y = 0.45 + 0.18 * i
        begin = 0.7 + 0.25 * i
        t.add(text(f"num{i}", f"tip{i + 1}Num", num, num, 0.042,
                   x=0.17, y=y, w=0.16, h=0.07, font="AvenirNext-Heavy",
                   role="accent", align="left", start=begin,
                   anims=[pop(1.1, 0.45)]))
        t.add(text(f"tip{i}", f"tip{i + 1}", tr_text, en_text, 0.034,
                   x=0.60, y=y, w=0.66, h=0.11, font="AvenirNext-Medium",
                   align="left", lines=2, start=begin + 0.05,
                   anims=[slide_in("right", 0.04, 0.5)]))
    t.add(text("footer", "footer", "Kaydet, akşam dene", "Save this, try it tonight", 0.02,
               y=0.925, w=0.8, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 14 — Üstte foto, altta bilet hissi veren panel (yırtma çizgisi + buton).
def webinar_invite():
    t = Template("webinar-invite-01", tr="Webinar Daveti", en="Webinar Invite",
                 category="education", track="calm-01",
                 palette=PALETTES["ocean"], duration=7.0)
    t.color("ink", "#3A5A66")
    t.add(bg())
    t.add(media("photo", 0, y=0.245, h=0.49, filter="cool", intensity=0.4,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.09, direction="down")]))
    t.add(scrim("scrim", direction="up", y=0.12, h=0.24))
    t.add(text("live", "live", "CANLI YAYIN", "LIVE WEBINAR", 0.024,
               y=0.10, w=0.8, h=0.04, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.018,
               start=0.25, anims=[fade_in(0.5)]))
    t.add(shape("ticket", "surface", y=0.73, w=0.86, h=0.40, radius=0.035,
                start=0.4, anims=[slide_in("up", 0.06, 0.65)]))
    t.add(text("topic", "topic", "Instagram'da\nSatış Nasıl Artar?",
               "How to Sell More\non Instagram", 0.046,
               y=0.595, w=0.72, h=0.12, font="AvenirNext-Bold",
               role="background", lines=2, start=0.7,
               anims=[slide_in("up", 0.03, 0.55)]))
    t.add(shape("notch-left", "background", x=0.07, y=0.66, w=0.06, h=0.03375,
                mask="circle", start=0.6, anims=[fade_in(0.4)]))
    t.add(shape("notch-right", "background", x=0.93, y=0.66, w=0.06, h=0.03375,
                mask="circle", start=0.6, anims=[fade_in(0.4)]))
    t.add(shape("tear", "ink", y=0.66, w=0.70, h=0.002, opacity=0.4,
                start=0.75, anims=[wipe("right", 0.6)]))
    t.add(text("when", "when", "24 Eylül · 20.30", "Sept 24 · 8:30 PM", 0.03,
               y=0.715, w=0.7, h=0.05, font="AvenirNext-Heavy",
               role="accent", tracking=0.008, start=0.9,
               anims=[fade_in(0.5)]))
    t.add(text("length", "length", "45 dakika + soru-cevap", "45 minutes + live Q&A", 0.02,
               y=0.765, w=0.7, h=0.035, font="AvenirNext-Regular",
               role="ink", start=1.05, anims=[fade_in(0.5)]))
    t.add(shape("cta-button", "accent", y=0.855, w=0.62, h=0.095, radius=0.047,
                start=1.1, anims=[pop(1.08, 0.5)]))
    t.add(text("cta", "cta", "Ücretsiz Katıl", "Join Free", 0.032,
               y=0.855, w=0.58, h=0.055, font="AvenirNext-Heavy",
               role="textOnAccent", start=1.2, anims=[fade_in(0.4)]))
    return t


# ---------------------------------------------------------------- business

# 15 — Tam kadraj ekip fotosu + çağrı + pozisyon rozeti + başvuru satırı.
def team_hiring():
    t = Template("team-hiring-01", tr="İş İlanı", en="We're Hiring",
                 category="business", track="upbeat-01",
                 palette=PALETTES["sunset"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.4,
                anims=[fade_in(0.5), ken_burns(6.5, zoom=1.1, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.12, h=0.24))
    t.add(scrim("scrim-bottom"))
    t.add(text("terms", "terms", "TAM ZAMANLI · İSTANBUL", "FULL-TIME · HYBRID", 0.022,
               y=0.10, w=0.86, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.016,
               start=0.25, anims=[typewriter(1.0)]))
    t.add(text("headline", "headline", "EKİBİMİZE\nKATIL", "JOIN OUR\nTEAM", 0.075,
               y=0.715, w=0.86, h=0.18, font="AvenirNext-Heavy",
               caps=True, lines=2, start=0.6,
               anims=[slide_in("up", 0.05, 0.6)]))
    t.add(shape("chip", "accent", y=0.855, w=0.66, h=0.085, radius=0.042,
                start=0.95, anims=[pop(1.1, 0.5)]))
    t.add(text("role", "role", "Kıdemli Grafik Tasarımcı", "Senior Graphic Designer", 0.028,
               y=0.855, w=0.62, h=0.05, font="AvenirNext-Bold",
               role="textOnAccent", start=1.1, anims=[fade_in(0.4)]))
    t.add(text("apply", "apply", "Başvuru: kariyer@sirket.com", "Apply: careers@studio.com", 0.021,
               y=0.935, w=0.86, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


TEMPLATES = [
    salon_booking, beauty_before_after, nail_art, spa_calm,
    gym_offer, workout_steps, run_stats, transformation,
    open_house, property_specs, for_rent,
    course_promo, lesson_tips, webinar_invite,
    team_hiring,
]
