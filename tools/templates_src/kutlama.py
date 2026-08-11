"""KUTLAMA BATCH — bayram/düğün/moda/müzik şablonları (15 adet).

Aileler:
  holiday  — bayram, sevgililer, ramazan
  wedding  — save the date, nişan, bebek, mezuniyet, yıl dönümü
  fashion  — lookbook, kombin ızgarası, deneme kabini, indirim
  music    — yeni şarkı, şarkı sözü, konser afişi

Düzenler bilinçli olarak farklı iskeletlerden seçildi: halkalı tipografi
kartı, maskeli portre, kolaj ızgara, hızlı kesme montajı, poster.
"""

from templatelib import *   # noqa: F403


# --------------------------------------------------------------- holiday

# 1 — Medyasız tebrik kartı: iç içe iki ince altın halka + serif tebrik.
def bayram_greeting():
    t = Template("bayram-greeting-01", tr="Bayram Tebriği", en="Holiday Greeting",
                 category="holiday", track="calm-01",
                 palette=PALETTES["charcoal"], duration=6.5)
    t.add(bg())
    t.add(shape("halo", "accent", y=0.5, w=0.92, h=0.5175, mask="circle",
                opacity=0.07, anims=[scale_in(0.82, 1.0), pulse(3.2, 1.04)]))
    t.add(shape("ring1-out", "accent", y=0.5, w=0.78, h=0.4388, mask="circle",
                anims=[scale_in(0.9, 0.7)]))
    t.add(shape("ring1-in", "background", y=0.5, w=0.762, h=0.4286, mask="circle",
                anims=[scale_in(0.9, 0.7)]))
    t.add(shape("ring2-out", "accent", y=0.5, w=0.70, h=0.3938, mask="circle",
                start=0.25, anims=[scale_in(0.88, 0.7)]))
    t.add(shape("ring2-in", "background", y=0.5, w=0.688, h=0.387, mask="circle",
                start=0.25, anims=[scale_in(0.88, 0.7)]))
    t.add(shape("gem-top", "accent", y=0.2806, w=0.026, h=0.0146, mask="circle",
                start=0.7, anims=[pop(1.2, 0.45)]))
    t.add(shape("gem-bottom", "accent", y=0.7194, w=0.026, h=0.0146, mask="circle",
                start=0.8, anims=[pop(1.2, 0.45)]))
    t.add(text("kicker", "kicker", "HAYIRLI BAYRAMLAR", "SEASON'S BLESSINGS", 0.021,
               y=0.395, w=0.66, h=0.04, font="AvenirNext-Medium",
               role="accent", caps=True, tracking=0.012,
               start=0.55, anims=[fade_in(0.6)]))
    t.add(text("title", "title", "Bayramınız\nKutlu Olsun", "A Blessed\nHoliday", 0.066,
               y=0.50, w=0.68, h=0.16, font="Georgia-Bold", lines=2,
               start=0.7, anims=[slide_in("up", 0.035, 0.7)]))
    t.add(shape("rule", "accent", y=0.60, w=0.09, h=0.004,
                start=1.0, anims=[wipe("right", 0.55)]))
    t.add(text("sub", "sub", "Sağlıkla, huzurla nice bayramlara",
               "To many more, in health and peace", 0.021,
               y=0.648, w=0.62, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    t.add(text("sign", "sign", "AİLECEK SEVGİLERİMİZLE", "WITH LOVE FROM OUR FAMILY",
               0.019, y=0.80, w=0.76, h=0.04, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.01,
               start=1.2, anims=[fade_in(0.7)]))
    return t


# 2 — Kalp maskeli portre + çevresinde küçük kalp sticker'lar.
def valentines():
    t = Template("valentines-01", tr="Sevgililer Günü", en="Valentine's",
                 category="holiday", track="sweet-01",
                 palette=PALETTES["rose"], pro=True, duration=7.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.40, w=0.96, h=0.54, mask="circle",
                opacity=0.16, anims=[scale_in(0.85, 0.9), pulse(2.6, 1.05)]))
    t.add(media("portrait", 0, y=0.40, w=0.74, h=0.42, mask="heart",
                filter="warm", intensity=0.5,
                anims=[scale_in(0.88, 0.7), ken_burns(7.0, zoom=1.10, direction="up")]))
    t.add(scrim("scrim", direction="down", y=0.78, h=0.44))
    t.add(text("kicker", "kicker", "SEVGİLİLER GÜNÜ", "VALENTINE'S DAY", 0.022,
               y=0.115, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.014,
               start=0.35, anims=[fade_in(0.6)]))
    hearts = [("h1", 0.14, 0.22, -14, 0.5), ("h2", 0.86, 0.26, 12, 0.65),
              ("h3", 0.10, 0.55, 10, 0.8), ("h4", 0.90, 0.58, -8, 0.95)]
    for lid, hx, hy, rot, delay in hearts:
        t.add(sticker(lid, lid, "❤️", size=0.045, x=hx, y=hy, rotation=rot,
                      start=delay, anims=[pop(1.25, 0.5), pulse(2.0, 1.08)]))
    t.add(text("names", "names", "Ayşe & Mehmet", "Ayşe & Mehmet", 0.072,
               y=0.72, w=0.8, h=0.12, font="SnellRoundhand-Bold",
               start=0.9, anims=[slide_in("up", 0.04, 0.7)]))
    t.add(text("note", "note", "İyi ki varsın", "Glad you're mine", 0.024,
               y=0.82, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    t.add(text("date", "date", "14 Şubat 2026", "February 14, 2026", 0.02,
               y=0.90, w=0.6, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.006,
               start=1.2, anims=[fade_in(0.6)]))
    return t


# 3 — Gece mavisi + altın; hilal hissi veren daireler, altta iftar satırı.
def ramadan():
    t = Template("ramadan-01", tr="Ramazan", en="Ramadan",
                 category="holiday", track="cinematic-01",
                 palette=PALETTES["midnight"], pro=True, duration=7.5)
    t.color("gold", "#E4C06A")
    t.color("goldSoft", "#E4C06A")
    t.add(bg())
    # Gökyüzü parıltısı kadrajın üst kenarına oturur (y merkezi = yükseklik/2),
    # yoksa katman ekranın dışına taşıyor.
    t.add(shape("sky", "gold", y=0.31, w=1.0, h=0.62, opacity=0.06,
                gradient={"from": "gold", "to": "background", "direction": "down"}))
    t.add(shape("moon", "gold", x=0.47, y=0.27, w=0.34, h=0.1913, mask="circle",
                anims=[scale_in(0.8, 0.8)]))
    t.add(shape("moon-cut", "background", x=0.565, y=0.255, w=0.30, h=0.1688,
                mask="circle", anims=[scale_in(0.8, 0.8)]))
    for i, (sx, sy, sw) in enumerate([(0.20, 0.16, 0.018), (0.78, 0.13, 0.012),
                                      (0.84, 0.33, 0.016), (0.16, 0.36, 0.011)]):
        t.add(shape(f"star{i}", "gold", x=sx, y=sy, w=sw, h=sw * 0.5625,
                    mask="circle", start=0.4 + 0.12 * i,
                    anims=[pop(1.3, 0.4), pulse(2.4 + 0.3 * i, 1.15)]))
    t.add(text("kicker", "kicker", "HOŞ GELDİN RAMAZAN", "RAMADAN KAREEM", 0.022,
               y=0.445, w=0.8, h=0.04, font="AvenirNext-Medium",
               role="gold", caps=True, tracking=0.014,
               start=0.6, anims=[fade_in(0.6)]))
    t.add(text("title", "title", "Ramazanınız\nMübarek Olsun", "A Blessed\nRamadan", 0.062,
               y=0.55, w=0.82, h=0.16, font="Georgia-Bold", lines=2,
               start=0.75, anims=[slide_in("up", 0.035, 0.7)]))
    t.add(shape("rule", "gold", y=0.645, w=0.10, h=0.004,
                start=1.05, anims=[wipe("right", 0.55)]))
    t.add(shape("chip", "gold", y=0.735, w=0.60, h=0.09, radius=0.045,
                opacity=0.14, start=1.0, anims=[scale_in(0.9, 0.5)]))
    t.add(text("iftar-label", "iftarLabel", "İFTAR VAKTİ", "IFTAR", 0.023,
               x=0.38, y=0.735, w=0.26, h=0.05, font="AvenirNext-Medium",
               role="textSecondary", align="left", caps=True, tracking=0.008,
               start=1.15, anims=[fade_in(0.5)]))
    t.add(text("iftar-time", "iftarTime", "19:42", "19:42", 0.032,
               x=0.66, y=0.735, w=0.22, h=0.05, font="AvenirNext-Heavy",
               role="gold", align="right",
               start=1.2, anims=[fade_in(0.5)]))
    t.add(text("sub", "sub", "Bereketli ve huzurlu günler dileriz",
               "Wishing you peaceful and blessed days", 0.021,
               y=0.845, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.3, anims=[fade_in(0.7)]))
    return t


# --------------------------------------------------------------- wedding

# 4 — Tam kadraj foto, üstte çift çizgi, ortada dev tarih, altta el yazısı isim.
def save_the_date():
    t = Template("save-the-date-01", tr="Tarihi Ayır", en="Save the Date",
                 category="wedding", track="acoustic-01",
                 palette=PALETTES["ivory"], duration=7.5)
    t.add(bg("textPrimary"))
    t.add(media("photo", 0, filter="fade", intensity=0.3,
                anims=[fade_in(0.8), ken_burns(7.5, zoom=1.10, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.18, h=0.36))
    t.add(scrim("scrim-bottom", direction="down", y=0.72, h=0.56))
    t.add(shape("rule-a", "surface", y=0.236, w=0.30, h=0.0035,
                start=0.35, anims=[wipe("right", 0.6)]))
    t.add(shape("rule-b", "surface", y=0.252, w=0.30, h=0.0035,
                start=0.45, anims=[wipe("left", 0.6)]))
    t.add(text("kicker", "kicker", "TARİHİ AYIRIN", "SAVE THE DATE", 0.024,
               y=0.305, w=0.8, h=0.045, font="AvenirNext-Medium",
               role="surface", caps=True, tracking=0.016,
               start=0.55, anims=[fade_in(0.7)]))
    t.add(text("date", "date", "12.06.2026", "06.12.2026", 0.082,
               y=0.50, w=0.88, h=0.14, font="Didot", role="surface",
               tracking=0.01, start=0.7, anims=[scale_in(0.86, 0.8)]))
    t.add(text("names", "names", "Ayşe & Mehmet", "Ayşe & Mehmet", 0.066,
               y=0.76, w=0.82, h=0.12, font="SnellRoundhand-Bold", role="surface",
               start=0.95, anims=[slide_in("up", 0.04, 0.7)]))
    t.add(text("venue", "venue", "Çeşme, İzmir", "Çeşme, Izmir", 0.022,
               y=0.865, w=0.7, h=0.04, font="AvenirNext-Regular",
               role="surface", tracking=0.008,
               start=1.15, anims=[fade_in(0.6)]))
    return t


# 5 — Montaj: foto sahnesi → tipografi kartı, crossDissolve.
def engagement():
    t = Template("engagement-01", tr="Nişan Duyurusu", en="Engagement",
                 category="wedding", track="sweet-01",
                 palette=PALETTES["blush"], pro=True)

    s1 = t.scene("moment", 3.4, transition="crossDissolve", transition_duration=0.5)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    s1.add(media("s1-photo", 0, filter="warm", intensity=0.4,
                 anims=[fade_in(0.7), ken_burns(3.4, zoom=1.12, direction="down")]))
    s1.add(scrim("s1-scrim", direction="down", y=0.72, h=0.56))
    s1.add(text("s1-word", "announce", "NİŞANLANDIK", "WE'RE ENGAGED", 0.052,
                y=0.80, w=0.86, h=0.10, font="AvenirNext-Heavy", role="surface",
                caps=True, tracking=0.012,
                start=0.4, anims=[slide_in("up", 0.05, 0.6)]))
    s1.add(text("s1-date", "date", "12 Haziran 2026", "June 12, 2026", 0.021,
                y=0.89, w=0.7, h=0.04, font="AvenirNext-Medium",
                role="surface", tracking=0.008,
                start=0.75, anims=[fade_in(0.6)]))

    s2 = t.scene("card", 3.2)
    s2.add(bg("background", "s2-bg"))
    s2.add(shape("s2-ring-out", "accent", y=0.42, w=0.52, h=0.2925, mask="circle",
                 anims=[scale_in(0.86, 0.7)]))
    s2.add(shape("s2-ring-in", "background", y=0.42, w=0.505, h=0.2841, mask="circle",
                 anims=[scale_in(0.86, 0.7)]))
    s2.add(sticker("s2-ring-emoji", "ring", "💍", size=0.075, x=0.5, y=0.42,
                   start=0.3, anims=[bounce(0.7)]))
    s2.add(text("s2-names", "names", "Ayşe & Mehmet", "Ayşe & Mehmet", 0.072,
                y=0.62, w=0.82, h=0.12, font="SnellRoundhand-Bold",
                role="textPrimary", start=0.45, anims=[slide_in("up", 0.04, 0.6)]))
    s2.add(shape("s2-rule", "accent", y=0.71, w=0.10, h=0.004,
                 start=0.75, anims=[wipe("right", 0.5)]))
    s2.add(text("s2-sub", "sub", "Sizi de aramızda görmek isteriz",
                "We'd love to have you with us", 0.022,
                y=0.775, w=0.78, h=0.045, font="AvenirNext-Regular",
                role="textSecondary", start=0.9, anims=[fade_in(0.6)]))
    return t


# 6 — Yumuşak pastel, daire maskeli portre, üstte "MÜJDE".
def baby_news():
    t = Template("baby-news-01", tr="Bebek Müjdesi", en="Baby News",
                 category="wedding", track="playful-01",
                 palette=PALETTES["cream"], duration=7.0)
    t.color("pastel", "#BCD9E4")
    t.add(bg())
    t.add(shape("wash", "pastel", y=0.47, w=1.0, h=0.72, opacity=0.35,
                gradient={"from": "pastel", "to": "background", "direction": "down"}))
    t.add(sticker("baby", "baby", "👶", size=0.05, x=0.5, y=0.075,
                  start=0.3, anims=[bounce(0.7)]))
    t.add(text("headline", "headline", "MÜJDE", "GOOD NEWS", 0.05,
               y=0.17, w=0.8, h=0.05, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.02,
               start=0.45, anims=[pop(1.1, 0.55)]))
    t.add(text("sub", "sub", "Ailemize küçük bir misafir geliyor",
               "A little one is joining our family", 0.022,
               y=0.245, w=0.82, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.6, anims=[fade_in(0.6)]))
    t.add(shape("ring", "pastel", y=0.47, w=0.72, h=0.405, mask="circle",
                anims=[scale_in(0.86, 0.8), pulse(3.0, 1.03)]))
    t.add(media("portrait", 0, y=0.47, w=0.68, h=0.3825, mask="circle",
                filter="warm", intensity=0.35,
                anims=[scale_in(0.9, 0.7), ken_burns(7.0, zoom=1.08, direction="up")]))
    t.add(text("name", "name", "Deniz", "Deniz", 0.075,
               y=0.75, w=0.7, h=0.11, font="SnellRoundhand-Bold",
               role="textPrimary", start=0.9, anims=[slide_in("up", 0.035, 0.7)]))
    t.add(text("date", "date", "Ekim 2026'da aramızda", "Arriving October 2026", 0.023,
               y=0.86, w=0.76, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    return t


# 7 — Tam kadraj + eğik kep sticker + dev yıl + okul satırı.
def graduation():
    t = Template("graduation-01", tr="Mezuniyet", en="Graduation",
                 category="wedding", track="anticipation-01",
                 palette=PALETTES["midnight"], duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, filter="cool", intensity=0.35,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.14, direction="down")]))
    t.add(scrim("scrim-top", direction="up", y=0.16, h=0.32))
    t.add(scrim("scrim-bottom", direction="down", y=0.70, h=0.60))
    t.add(sticker("cap", "cap", "🎓", size=0.10, x=0.5, y=0.22, rotation=-12,
                  start=0.3, anims=[bounce(0.8)]))
    t.add(text("kicker", "kicker", "MEZUN OLDUM", "I GRADUATED", 0.026,
               y=0.36, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.018,
               start=0.5, anims=[fade_in(0.6)]))
    t.add(text("year", "year", "2026", "2026", 0.152,
               y=0.50, w=0.9, h=0.20, font="AvenirNext-Heavy",
               tracking=0.004, start=0.6, anims=[scale_in(0.82, 0.7)]))
    t.add(shape("rule", "accent", y=0.635, w=0.14, h=0.005,
                start=0.9, anims=[wipe("right", 0.6)]))
    t.add(text("name", "name", "Ayşe Yılmaz", "Ayşe Yılmaz", 0.05,
               y=0.72, w=0.86, h=0.09, font="AvenirNext-Bold",
               start=0.95, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("school", "school", "İstanbul Üniversitesi · Mimarlık",
               "University of Istanbul · Architecture", 0.023,
               y=0.81, w=0.88, h=0.045, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    t.add(text("tagline", "tagline", "Yeni bir sayfa açılıyor", "A new chapter begins",
               0.02, y=0.885, w=0.76, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.006,
               start=1.2, anims=[fade_in(0.7)]))
    return t


# 8 — Montaj: "1 YIL ÖNCE" → "BUGÜN", blurDissolve.
def anniversary():
    t = Template("anniversary-01", tr="Yıl Dönümü", en="Anniversary",
                 category="wedding", track="dreamy-01",
                 palette=PALETTES["sand"], pro=True)

    then = t.scene("then", 3.5, transition="blurDissolve", transition_duration=0.6)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş).
    then.add(media("then-photo", 0, y=0.44, w=0.84, h=0.56, radius=0.012,
                   filter="vintage", intensity=0.65,
                   anims=[fade_in(0.6), ken_burns(3.5, zoom=1.08, direction="up")]))
    then.add(text("then-label", "thenLabel", "1 YIL ÖNCE", "ONE YEAR AGO", 0.042,
                  y=0.80, w=0.82, h=0.08, font="AvenirNext-Heavy",
                  role="accent", caps=True, tracking=0.016,
                  start=0.35, anims=[slide_in("up", 0.04, 0.6)]))
    then.add(text("then-sub", "thenSub", "İlk günümüz", "Our first day", 0.022,
                  y=0.885, w=0.7, h=0.04, font="AvenirNext-Regular",
                  role="textSecondary", start=0.7, anims=[fade_in(0.6)]))

    now = t.scene("now", 3.3)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş).
    now.add(media("now-photo", 1, y=0.44, w=0.84, h=0.56, radius=0.012,
                  filter="warm", intensity=0.35,
                  anims=[fade_in(0.6), ken_burns(3.3, zoom=1.08, direction="down")]))
    now.add(text("now-label", "nowLabel", "BUGÜN", "TODAY", 0.05,
                 y=0.80, w=0.82, h=0.09, font="AvenirNext-Heavy",
                 role="textPrimary", caps=True, tracking=0.016,
                 start=0.3, anims=[pop(1.08, 0.55)]))
    now.add(text("now-sub", "nowSub", "Ayşe & Mehmet · 1. yıl",
                 "Ayşe & Mehmet · Year one", 0.022,
                 y=0.885, w=0.76, h=0.04, font="AvenirNext-Medium",
                 role="textSecondary", start=0.65, anims=[fade_in(0.6)]))
    return t


# --------------------------------------------------------------- fashion

# 9 — Montaj: üç kombin, köşede numara etiketi, slideLeft.
def lookbook():
    t = Template("lookbook-01", tr="Kombin Defteri", en="Lookbook",
                 category="fashion", track="chill-01",
                 palette=PALETTES["paper"])
    looks = [
        ("01", "SABAH", "MORNING", "Kahve ve keten", "Coffee and linen", "warm"),
        ("02", "ÖĞLEDEN SONRA", "AFTERNOON", "Şehirde yürüyüş", "A walk in town", "fade"),
        ("03", "AKŞAM", "EVENING", "Sadece siyah", "Nothing but black", "mono"),
    ]
    for i, (num, tr_label, en_label, tr_title, en_title, filt) in enumerate(looks):
        last = i == len(looks) - 1
        s = t.scene(f"look{i}", 2.6,
                    transition=None if last else "slideLeft",
                    transition_duration=0.4)
        # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
        # compositor paletteki background'ı zaten boyar.
        s.add(media(f"look{i}-media", i, filter=filt, intensity=0.45,
                    anims=[fade_in(0.4),
                           ken_burns(2.6, zoom=1.09,
                                     direction="up" if i % 2 == 0 else "down")]))
        s.add(scrim(f"look{i}-scrim-top", direction="up", y=0.12, h=0.24))
        s.add(scrim(f"look{i}-scrim", direction="down", y=0.76, h=0.48))
        s.add(shape(f"look{i}-tag", "accent", x=0.155, y=0.13, w=0.15, h=0.075,
                    radius=0.008, anims=[scale_in(0.7, 0.4)]))
        s.add(text(f"look{i}-num", "lookNumber", num, num, 0.034,
                   x=0.155, y=0.13, w=0.13, h=0.05, font="Archivo-SemiBold",
                   role="surface", start=0.2, anims=[fade_in(0.35)]))
        s.add(text(f"look{i}-label", "lookLabel", tr_label, en_label, 0.021,
                   y=0.83, w=0.82, h=0.04, font="AvenirNext-Medium",
                   role="surface", caps=True, tracking=0.014,
                   start=0.25, anims=[wipe("right", 0.5)]))
        s.add(text(f"look{i}-title", "lookTitle", tr_title, en_title, 0.038,
                   y=0.89, w=0.86, h=0.06, font="Archivo-SemiBold",
                   role="surface", start=0.4, anims=[slide_in("up", 0.04, 0.5)]))
    return t


# 10 — Montaj tek sahne: 2x2 ızgara + ortada marka rozeti.
def outfit_grid():
    t = Template("outfit-grid-01", tr="Kombin Izgarası", en="Outfit Grid",
                 category="fashion", track="clean-01",
                 palette=PALETTES["mono"], pro=True)
    s = t.scene("grid", 6.0)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    cells = [(0.2525, 0.2575), (0.7475, 0.2575), (0.2525, 0.7425), (0.7475, 0.7425)]
    for i, (x, y) in enumerate(cells):
        s.add(media(f"cell{i}", i, x=x, y=y, w=0.495, h=0.4925, radius=0.006,
                    filter="mono" if i % 2 else None, intensity=0.3 if i % 2 else None,
                    anims=[scale_in(0.9, 0.5, delay=0.09 * i),
                           ken_burns(6.0, zoom=1.06,
                                     direction=["up", "down", "left", "right"][i])]))
    s.add(shape("brand-chip", "surface", y=0.5, w=0.56, h=0.095, radius=0.0475,
                start=0.55, anims=[pop(1.07, 0.5)]))
    s.add(text("brand", "brand", "ATÖLYE ON İKİ", "STUDIO TWELVE", 0.032,
               y=0.5, w=0.52, h=0.06, font="Archivo-SemiBold",
               role="background", caps=True, tracking=0.012,
               start=0.7, anims=[fade_in(0.4)]))
    s.add(shape("season-chip", "background", y=0.588, w=0.34, h=0.055,
                radius=0.0275, opacity=0.9,
                start=0.85, anims=[scale_in(0.85, 0.45)]))
    s.add(text("season", "season", "SONBAHAR 26", "FALL 26", 0.024,
               y=0.588, w=0.32, h=0.04, font="AvenirNext-DemiBold",
               role="textPrimary", caps=True, tracking=0.014,
               start=0.95, anims=[fade_in(0.4)]))
    return t


# 11 — Montaj: üç hızlı kesme, her sahnede fiyat etiketi.
def try_on():
    t = Template("try-on-01", tr="Deneme Kabini", en="Try-On",
                 category="fashion", track="punchy-01",
                 palette=PALETTES["punch"], pro=True)
    looks = [
        (1.6, "DENEME 01", "LOOK 01", "₺349", "$29", "Keten gömlek", "Linen shirt"),
        (1.6, "DENEME 02", "LOOK 02", "₺499", "$39", "Yüksek bel pantolon",
         "High-waist trousers"),
        (1.8, "DENEME 03", "LOOK 03", "₺899", "$69", "Uzun trençkot", "Long trench coat"),
    ]
    for i, (dur, tr_label, en_label, tr_price, en_price, tr_name, en_name) in \
            enumerate(looks):
        last = i == len(looks) - 1
        s = t.scene(f"fit{i}", dur,
                    transition=None if last else "cut", transition_duration=0.12)
        # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
        # compositor paletteki background'ı zaten boyar.
        s.add(media(f"fit{i}-media", i, filter="vivid", intensity=0.4,
                    anims=[ken_burns(dur, zoom=1.08,
                                     direction="up" if i % 2 == 0 else "left")]))
        s.add(scrim(f"fit{i}-scrim-top", direction="up", y=0.11, h=0.22))
        s.add(scrim(f"fit{i}-scrim", direction="down", y=0.80, h=0.40))
        s.add(shape(f"fit{i}-label-chip", "surface", x=0.22, y=0.14, w=0.30, h=0.065,
                    radius=0.0325, anims=[scale_in(0.8, 0.3)]))
        s.add(text(f"fit{i}-label", "fitLabel", tr_label, en_label, 0.024,
                   x=0.22, y=0.14, w=0.28, h=0.045, font="AvenirNext-Heavy",
                   role="background", caps=True, tracking=0.008,
                   start=0.12, anims=[fade_in(0.25)]))
        s.add(shape(f"fit{i}-price-chip", "accent", x=0.78, y=0.14, w=0.28, h=0.075,
                    radius=0.0375, rotation=-7, start=0.15, anims=[pop(1.15, 0.35)]))
        s.add(text(f"fit{i}-price", "fitPrice", tr_price, en_price, 0.034,
                   x=0.78, y=0.14, w=0.26, h=0.05, font="AvenirNext-Heavy",
                   role="textOnAccent", rotation=-7,
                   start=0.22, anims=[fade_in(0.25)]))
        s.add(text(f"fit{i}-name", "fitName", tr_name, en_name, 0.038,
                   y=0.86, w=0.86, h=0.065, font="AvenirNext-Bold",
                   start=0.2, anims=[slide_in("up", 0.05, 0.35)]))
        s.add(text(f"fit{i}-hint", "fitHint", "Hangisi olsun?", "Which one?", 0.02,
                   y=0.935, w=0.7, h=0.035, font="AvenirNext-Medium",
                   role="textSecondary", start=0.3, anims=[fade_in(0.35)]))
    return t


# 12 — Tam kadraj + dev eğik yüzde + altta indirim şeridi.
def sale_rack():
    t = Template("sale-rack-01", tr="İndirim Reyonu", en="Sale Rack",
                 category="fashion", track="energetic-01",
                 palette=PALETTES["citrus"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="vivid", intensity=0.55,
                anims=[fade_in(0.4), ken_burns(6.0, zoom=1.14, direction="left")]))
    t.add(scrim("scrim-top", direction="up", y=0.18, h=0.36))
    t.add(scrim("scrim", direction="down", y=0.74, h=0.52))
    t.add(text("kicker", "kicker", "SEZON SONU", "END OF SEASON", 0.028,
               y=0.26, w=0.82, h=0.045, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.02,
               start=0.25, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(text("percent", "percent", "%50", "50%", 0.168,
               y=0.42, w=0.92, h=0.24, font="AvenirNext-Heavy",
               rotation=-8, start=0.4, anims=[pop(1.12, 0.6)]))
    t.add(shape("band", "accent", y=0.68, w=1.0, h=0.10,
                start=0.7, anims=[wipe("right", 0.55)]))
    t.add(text("band-text", "bandText", "TÜM YAZLIKLAR", "ALL SUMMER STYLES", 0.042,
               y=0.68, w=0.92, h=0.07, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.01,
               start=0.9, anims=[fade_in(0.4)]))
    t.add(text("note", "note", "31 Ağustos'a kadar · Mağazada ve online",
               "Until August 31 · In store and online", 0.021,
               y=0.80, w=0.9, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.05, anims=[fade_in(0.6)]))
    t.add(text("handle", "handle", "@markaniz", "@yourbrand", 0.02,
               y=0.89, w=0.7, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.006,
               start=1.15, anims=[fade_in(0.6)]))
    return t


# ----------------------------------------------------------------- music

# 13 — Kare albüm kapağı + şarkı/sanatçı + dalga çubukları.
def track_drop():
    t = Template("track-drop-01", tr="Yeni Şarkı", en="Track Drop",
                 category="music", track="beat-01",
                 palette=PALETTES["neon"], duration=7.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.40, w=0.96, h=0.54, mask="circle",
                opacity=0.14, anims=[scale_in(0.85, 0.9), pulse(2.2, 1.06)]))
    t.add(text("kicker", "kicker", "YENİ ŞARKI", "NEW TRACK", 0.026,
               y=0.13, w=0.8, h=0.045, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.024,
               start=0.3, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(media("cover", 0, y=0.40, w=0.68, h=0.3825, radius=0.012,
                filter="vivid", intensity=0.5,
                anims=[scale_in(0.88, 0.7), ken_burns(7.0, zoom=1.06, direction="up")]))
    t.add(text("title", "title", "Gece Yarısı", "Midnight Hour", 0.062,
               y=0.68, w=0.88, h=0.11, font="AvenirNext-Heavy",
               start=0.6, anims=[slide_in("up", 0.045, 0.6)]))
    t.add(text("artist", "artist", "MERT KAYA", "MERT KAYA", 0.024,
               y=0.775, w=0.74, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.018,
               start=0.8, anims=[fade_in(0.6)]))
    bar_heights = [0.028, 0.046, 0.062, 0.038, 0.070, 0.034, 0.058, 0.044, 0.026]
    for i, bh in enumerate(bar_heights):
        t.add(shape(f"bar{i}", "accent", x=0.34 + 0.04 * i, y=0.88,
                    w=0.011, h=bh, radius=0.0055,
                    start=0.9 + 0.05 * i,
                    anims=[scale_in(0.4, 0.35),
                           pulse(0.7 + 0.09 * i, 1.55, axis="y")]))
    t.add(text("footer", "footer", "Tüm dijital platformlarda", "Out now everywhere",
               0.02, y=0.945, w=0.8, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.7)]))
    return t


# 14 — Yumuşatılmış tam kadraj foto + dev serif şarkı sözü.
def lyric_card():
    t = Template("lyric-card-01", tr="Şarkı Sözü", en="Lyric Card",
                 category="music", track="smooth-01",
                 palette=PALETTES["grape"], pro=True, duration=8.0)
    t.add(bg())
    t.add(media("photo", 0, filter="fade", intensity=0.85,
                anims=[fade_in(0.8), ken_burns(8.0, zoom=1.06, direction="right")]))
    t.add(shape("veil", "background", opacity=0.55, anims=[fade_in(0.8)]))
    t.add(scrim("scrim", direction="up", y=0.30, h=0.60))
    t.add(text("kicker", "kicker", "ŞARKI SÖZÜ", "LYRIC", 0.021,
               y=0.24, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="accent", caps=True, tracking=0.022,
               start=0.35, anims=[fade_in(0.7)]))
    t.add(shape("rule", "accent", y=0.283, w=0.08, h=0.004,
                start=0.55, anims=[wipe("right", 0.6)]))
    t.add(text("lyric", "lyric",
               "Şehrin bütün\nışıkları sönse de\nsen kal.",
               "Even if every\nlight goes out,\nyou stay.", 0.058,
               y=0.46, w=0.84, h=0.30, font="Georgia-Italic", lines=3,
               start=0.7, anims=[slide_in("up", 0.03, 0.9)]))
    t.add(text("artist", "artist", "— Mert Kaya, “Gece Yarısı”",
               "— Mert Kaya, “Midnight Hour”", 0.022,
               y=0.70, w=0.82, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.7)]))
    t.add(text("footer", "footer", "Yeni albüm 12 Eylül'de", "New album, September 12",
               0.02, y=0.90, w=0.78, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.008,
               start=1.2, anims=[fade_in(0.8)]))
    return t


# 15 — Poster: üstte dev grup adı, ortada foto şerit, altta künye satırları.
def gig_poster():
    t = Template("gig-poster-01", tr="Konser Afişi", en="Gig Poster",
                 category="music", track="groovy-01",
                 palette=PALETTES["electric"], duration=8.0)
    t.add(bg())
    t.add(text("band", "band", "GECE\nORKESTRASI", "NIGHT\nORCHESTRA", 0.078,
               y=0.18, w=0.92, h=0.20, font="AvenirNext-Heavy", lines=2,
               caps=True, tracking=0.006,
               start=0.25, anims=[slide_in("down", 0.05, 0.7)]))
    t.add(shape("rule-top", "accent", y=0.31, w=0.92, h=0.005,
                start=0.6, anims=[wipe("right", 0.7)]))
    t.add(media("photo", 0, y=0.475, w=0.92, h=0.28, radius=0.006,
                filter="mono", intensity=0.7,
                anims=[fade_in(0.6), ken_burns(8.0, zoom=1.10, direction="left")]))
    t.add(shape("rule-bottom", "accent", y=0.645, w=0.92, h=0.005,
                start=0.75, anims=[wipe("left", 0.7)]))
    t.add(text("date", "date", "12 EYLÜL 2026", "SEPTEMBER 12, 2026", 0.046,
               y=0.71, w=0.90, h=0.08, font="Archivo-SemiBold",
               caps=True, tracking=0.01,
               start=0.85, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("venue", "venue", "İSTANBUL · KÜÇÜKÇİFTLİK PARK",
               "ISTANBUL · KUCUKCIFTLIK PARK", 0.024,
               y=0.79, w=0.92, h=0.045, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.012,
               start=1.0, anims=[fade_in(0.6)]))
    t.add(shape("ticket-chip", "accent", y=0.885, w=0.84, h=0.085, radius=0.0425,
                start=1.05, anims=[pop(1.06, 0.55)]))
    t.add(text("ticket", "ticket", "BİLETLER TÜKENMEK ÜZERE", "TICKETS SELLING FAST",
               0.026, y=0.885, w=0.80, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.01,
               start=1.2, anims=[fade_in(0.45)]))
    return t


TEMPLATES = [
    bayram_greeting, valentines, ramadan,
    save_the_date, engagement, baby_news, graduation, anniversary,
    lookbook, outfit_grid, try_on, sale_rack,
    track_drop, lyric_card, gig_poster,
]
