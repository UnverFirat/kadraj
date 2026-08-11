"""MINIMAL batch — 12 şablon.

Sade tipografi ve az öğe üstüne kurulu düzenler; birkaçı sosyal/kurumsal
kategoride ama hepsinin ortak yanı gürültüsüz kadraj. Her şablon farklı bir
iskelet kullanır: saf tipografi, gradient zemin, film şeridi, çerçeve, kâğıt
kart, neon tabela, kaset arayüzü, ritim montajı, altyazı şeridi, alıntı
bloğu, rakam kartı ve logo açılışı.
"""

from templatelib import *   # noqa: F403


# 1 — Kalın Söz: medyasız, ekranı dolduran tipografi + CapCut tarzı vurgu kutusu.
def bold_statement():
    t = Template("bold-statement-01", tr="Kalın Söz", en="Bold Statement",
                 category="minimal", track="impact-01",
                 palette=PALETTES["citrus"], pro=False, duration=6.0)
    t.add(bg())
    t.add(shape("tick", "accent", x=0.14, y=0.185, w=0.1, h=0.006,
                anims=[wipe("right", 0.5)]))
    t.add(text("kicker", "kicker", "GÜNÜN NOTU", "NOTE OF THE DAY", 0.024,
               x=0.5, y=0.235, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.01,
               start=0.2, anims=[fade_in(0.5)]))
    t.add(text("line1", "line1", "SESSİZCE", "QUIETLY", 0.095,
               y=0.36, w=0.88, h=0.115, font="AvenirNext-Heavy",
               caps=True, tracking=-0.002, start=0.35,
               anims=[slide_in("up", 0.05, 0.55)]))
    t.add(text("line2", "line2", "İYİ İŞLER", "DO GOOD", 0.095,
               y=0.485, w=0.88, h=0.115, font="AvenirNext-Heavy",
               role="textOnAccent", highlight="accent",
               caps=True, tracking=-0.002, start=0.6,
               anims=[wipe("right", 0.6)]))
    t.add(text("line3", "line3", "YAP.", "WORK.", 0.095,
               y=0.61, w=0.88, h=0.115, font="AvenirNext-Heavy",
               caps=True, tracking=-0.002, start=0.85,
               anims=[slide_in("up", 0.05, 0.55)]))
    t.add(text("sign", "sign", "— her sabah kendine hatırlat",
               "— remind yourself every morning", 0.02,
               y=0.755, w=0.82, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 2 — Yumuşak Geçiş: iki büyük gradient leke + ortada ince serif başlık.
def soft_gradient():
    t = Template("soft-gradient-01", tr="Yumuşak Geçiş", en="Soft Gradient",
                 category="minimal", track="calm-01",
                 palette=PALETTES["blush"], pro=False, duration=7.0)
    t.color("glowRose", "#F3C9C4")
    t.color("glowLilac", "#DCCBE8")
    t.color("glowPeach", "#F8DCC2")
    t.add(bg())
    t.add(shape("glow-a", "glowRose", x=0.34, y=0.34, w=0.72, h=0.42,
                mask="circle", opacity=0.65,
                gradient={"from": "glowRose", "to": "glowLilac",
                          "direction": "diagonal"},
                anims=[fade_in(1.0), pulse(3.4, 1.05)]))
    t.add(shape("glow-b", "glowPeach", x=0.66, y=0.62, w=0.72, h=0.44,
                mask="circle", opacity=0.55,
                gradient={"from": "glowPeach", "to": "glowRose",
                          "direction": "up"},
                anims=[fade_in(1.2, delay=0.2), pulse(4.2, 1.04)]))
    t.add(text("title", "title", "Yavaşla ve\nnefes al", "Slow down\nand breathe", 0.056,
               y=0.475, w=0.72, h=0.15, font="Didot", role="textPrimary",
               lines=2, start=0.5, anims=[scale_in(0.92, 0.9)]))
    t.add(shape("hair", "accent", y=0.585, w=0.07, h=0.003,
                start=1.0, anims=[wipe("right", 0.6)]))
    t.add(text("sub", "sub", "Acelesi olmayan bir pazar sabahı",
               "A Sunday morning with nowhere to be", 0.021,
               y=0.645, w=0.76, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.8)]))
    return t


# 3 — Film Şeridi: tek sahnede üç yatay şerit medya + perforasyon kareleri.
def film_strip():
    t = Template("film-strip-01", tr="Film Şeridi", en="Film Strip",
                 category="minimal", track="cinematic-01",
                 palette=PALETTES["mono"], pro=True)
    s = t.scene("strip", 7.0)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    for i, y in enumerate((0.28, 0.50, 0.72)):
        s.add(media(f"frame{i}", i, y=y, w=0.82, h=0.2,
                    filter="cinematic", intensity=0.45,
                    anims=[fade_in(0.6, delay=0.12 * i),
                           ken_burns(7.0, zoom=1.08,
                                     direction="left" if i % 2 else "right")]))
    for i in range(12):
        py = 0.15 + i * 0.064
        s.add(shape(f"perf-l{i}", "surface", x=0.06, y=py, w=0.034, h=0.017,
                    radius=0.004, opacity=0.8))
        s.add(shape(f"perf-r{i}", "surface", x=0.94, y=py, w=0.034, h=0.017,
                    radius=0.004, opacity=0.8))
    s.add(text("reel", "reel", "36 KARE, TEK GÜN", "36 FRAMES, ONE DAY", 0.032,
               y=0.095, w=0.76, h=0.055, font="AvenirNext-Heavy",
               caps=True, tracking=0.012, start=0.4,
               anims=[slide_in("down", 0.03, 0.6)]))
    s.add(text("roll", "roll", "rulo 01 · ağustos", "roll 01 · august", 0.02,
               y=0.905, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", tracking=0.008, start=0.9,
               anims=[fade_in(0.7)]))
    return t


# 4 — Siyah Beyaz: mono tam kadraj + dört kenardan ince beyaz çerçeve.
def mono_frame():
    t = Template("mono-frame-01", tr="Siyah Beyaz", en="Mono Frame",
                 category="minimal", track="ambient-01",
                 palette=PALETTES["mono"], pro=False, duration=6.5)
    t.add(bg())
    t.add(media("shot", 0, filter="mono", intensity=1.0,
                anims=[fade_in(0.8), ken_burns(6.5, zoom=1.07, direction="up")]))
    t.add(scrim("veil", direction="down", y=0.78, h=0.44))
    t.add(shape("edge-top", "surface", y=0.07, w=0.84, h=0.0035,
                start=0.3, anims=[wipe("right", 0.7)]))
    t.add(shape("edge-bottom", "surface", y=0.93, w=0.84, h=0.0035,
                start=0.3, anims=[wipe("left", 0.7)]))
    t.add(shape("edge-left", "surface", x=0.08, y=0.5, w=0.002, h=0.86,
                start=0.5, anims=[fade_in(0.7)]))
    t.add(shape("edge-right", "surface", x=0.92, y=0.5, w=0.002, h=0.86,
                start=0.5, anims=[fade_in(0.7)]))
    t.add(text("caption", "caption", "Gölgeler daha çok\nşey anlatıyor",
               "Shadows say more\nthan color does", 0.05,
               y=0.83, w=0.74, h=0.13, font="Georgia-Italic",
               lines=2, start=0.75, anims=[slide_in("up", 0.03, 0.7)]))
    t.add(text("date", "date", "10 AĞUSTOS 2026", "AUGUST 10, 2026", 0.019,
               y=0.925, w=0.7, h=0.033, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.014,
               start=1.15, anims=[fade_in(0.6)]))
    return t


# 5 — Not Kâğıdı: eğik beyaz kart, daktilo yazısı ve köşede bantlanmış foto.
def paper_note():
    t = Template("paper-note-01", tr="Not Kâğıdı", en="Paper Note",
                 category="minimal", track="typewriter-01",
                 palette=PALETTES["paper"], pro=True, duration=7.5)
    t.add(bg())
    t.add(shape("card-shadow", "textSecondary", x=0.515, y=0.475, w=0.82, h=0.6,
                radius=0.008, rotation=-2.5, opacity=0.18,
                anims=[fade_in(0.5)]))
    t.add(shape("card", "surface", y=0.46, w=0.82, h=0.6, radius=0.008,
                rotation=-2.5, anims=[scale_in(0.94, 0.6)]))
    t.add(text("stamp", "stamp", "10 AĞUSTOS · SALI", "AUGUST 10 · TUESDAY", 0.022,
               x=0.5, y=0.235, w=0.66, h=0.04, font="Courier-Bold",
               role="textSecondary", align="left", caps=True, tracking=0.006,
               rotation=-2.5, start=0.4, anims=[fade_in(0.5)]))
    t.add(shape("rule", "accent", y=0.275, w=0.66, h=0.002, rotation=-2.5,
                start=0.55, anims=[wipe("right", 0.6)]))
    t.add(text("note", "note",
               "Bugün küçük bir şey\ndenedim ve işe yaradı.\n"
               "Yarın biraz daha\nileri gideceğim.",
               "Tried one small thing\ntoday and it worked.\n"
               "Tomorrow I will push\na little further.", 0.034,
               x=0.5, y=0.405, w=0.68, h=0.22, font="Courier-Bold",
               role="textPrimary", align="left", lines=4, rotation=-2.5,
               start=0.7, anims=[typewriter(2.0)]))
    t.add(text("sign", "sign", "sevgiler, Ada", "love, Ada", 0.03,
               x=0.33, y=0.575, w=0.46, h=0.06, font="SnellRoundhand-Bold",
               role="accent", align="left", rotation=-2.5,
               start=2.9, anims=[fade_in(0.8)]))
    t.add(media("polaroid", 0, x=0.735, y=0.735, w=0.26, h=0.2, kind="photo",
                radius=0.006, rotation=5, filter="fade", intensity=0.3,
                anims=[pop(1.06, 0.6, delay=1.4), ken_burns(7.5, zoom=1.06)]))
    t.add(shape("tape", "textSecondary", x=0.735, y=0.645, w=0.11, h=0.024,
                rotation=5, opacity=0.35, start=1.4, anims=[fade_in(0.4)]))
    return t


# 6 — Neon Tabela: koyu zemin, neon yazı, arkada aynı renkte bulanık halka.
def neon_sign():
    t = Template("neon-sign-01", tr="Neon Tabela", en="Neon Sign",
                 category="social", track="chill-01",
                 palette=PALETTES["neon"], pro=True, duration=6.5)
    t.color("neonPink", "#FF4FD8")
    t.add(bg())
    t.add(shape("halo-wide", "accent", y=0.46, w=0.86, h=0.48, mask="circle",
                opacity=0.14, anims=[fade_in(1.0), pulse(2.8, 1.06)]))
    t.add(shape("halo-core", "accent", y=0.46, w=0.56, h=0.31, mask="circle",
                opacity=0.22, anims=[scale_in(0.75, 0.9), pulse(1.8, 1.05)]))
    t.add(text("kicker", "kicker", "CANLI MÜZİK VAR", "LIVE MUSIC TONIGHT", 0.026,
               y=0.325, w=0.82, h=0.045, font="AvenirNext-DemiBold",
               role="neonPink", caps=True, tracking=0.016,
               start=0.3, anims=[fade_in(0.6)]))
    t.add(text("sign", "sign", "GECE\nAÇIĞIZ", "OPEN\nALL NIGHT", 0.088,
               y=0.46, w=0.86, h=0.2, font="AvenirNext-Heavy",
               role="accent", lines=2, caps=True, tracking=0.004,
               start=0.55, anims=[pop(1.1, 0.6)]))
    t.add(text("hours", "hours", "HER GÜN 20:00 — 04:00", "EVERY DAY 8PM — 4AM", 0.023,
               y=0.615, w=0.82, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.012,
               start=1.0, anims=[slide_in("up", 0.03, 0.6)]))
    t.add(shape("underline", "neonPink", y=0.685, w=0.16, h=0.005,
                opacity=0.9, start=1.2, anims=[wipe("right", 0.6)]))
    t.add(text("where", "where", "Kadıköy · Moda Cad. 12",
               "Downtown · 12 Moda St.", 0.021,
               y=0.745, w=0.78, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.35, anims=[fade_in(0.7)]))
    return t


# 7 — Retro Kaset: vintage tam kadraj + REC göstergesi, zaman kodu, tarih damgası.
def retro_vhs():
    t = Template("retro-vhs-01", tr="Retro Kaset", en="Retro Tape",
                 category="social", track="groovy-01",
                 palette=PALETTES["retro"], pro=True, duration=7.0)
    t.color("recRed", "#FF3B30")
    t.add(bg())
    t.add(media("tape", 0, filter="vintage", intensity=0.85,
                anims=[fade_in(0.5), ken_burns(7.0, zoom=1.1, direction="down")]))
    t.add(scrim("veil-top", direction="up", y=0.13, h=0.26))
    t.add(scrim("veil-bottom", direction="down", y=0.79, h=0.42))
    t.add(shape("rec-dot", "recRed", x=0.115, y=0.095, w=0.026, h=0.0146,
                mask="circle", anims=[pulse(1.0, 1.25)]))
    t.add(text("rec", "rec", "REC", "REC", 0.028,
               x=0.215, y=0.095, w=0.15, h=0.04, font="Courier-Bold",
               role="recRed", align="left", caps=True, tracking=0.01,
               start=0.2, anims=[fade_in(0.4)]))
    t.add(text("timecode", "timecode", "00:00:12:04", "00:00:12:04", 0.028,
               x=0.79, y=0.095, w=0.34, h=0.04, font="Courier-Bold",
               role="textPrimary", align="right", tracking=0.004,
               start=0.2, anims=[fade_in(0.4)]))
    t.add(text("title", "title", "YAZIN SON GÜNÜ", "LAST DAY OF SUMMER", 0.048,
               y=0.825, w=0.84, h=0.09, font="Courier-Bold",
               role="textPrimary", caps=True, tracking=0.004,
               start=0.6, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("datestamp", "datestamp", "10 AĞU 2026", "AUG 10 2026", 0.026,
               y=0.905, w=0.8, h=0.042, font="Courier-Bold",
               role="accent", caps=True, tracking=0.02,
               start=0.95, anims=[typewriter(1.0)]))
    return t


# 8 — Ritim Zoom: dört kısa sahne, zoom geçişleri, sahne başına tek kelime.
def zoom_punch():
    t = Template("zoom-punch-01", tr="Ritim Zoom", en="Zoom Punch",
                 category="social", track="beat-01",
                 palette=PALETTES["punch"], pro=True)
    beats = [
        ("DUR", "STOP", "zoomIn"),
        ("BAK", "LOOK", "zoomOut"),
        ("ÇEK", "SHOOT", "zoomIn"),
        ("PAYLAŞ", "SHARE", None),
    ]
    for i, (tr_word, en_word, transition) in enumerate(beats):
        s = t.scene(f"beat{i}", 1.2, transition=transition,
                    transition_duration=0.25)
        # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
        # compositor paletteki background'ı zaten boyar.
        s.add(media(f"b{i}-media", i, filter="vivid", intensity=0.55,
                    anims=[ken_burns(1.2, zoom=1.16,
                                     direction="up" if i % 2 else "down")]))
        s.add(scrim(f"b{i}-scrim", direction="down", y=0.72, h=0.56))
        s.add(text(f"b{i}-word", f"word{i}", tr_word, en_word, 0.11,
                   y=0.5, w=0.9, h=0.15, font="AvenirNext-Heavy",
                   caps=True, tracking=0.004, start=0.12,
                   anims=[pop(1.12, 0.35)]))
        s.add(text(f"b{i}-step", f"step{i}", f"0{i + 1} / 04", f"0{i + 1} / 04", 0.024,
                   y=0.88, w=0.5, h=0.04, font="AvenirNext-DemiBold",
                   role="accent", tracking=0.012, start=0.25,
                   anims=[fade_in(0.3)]))
    return t


# 9 — Altyazı Şeridi: tam kadraj + dolgulu altyazı kutusu + üstte kullanıcı adı.
def caption_bar():
    t = Template("caption-bar-01", tr="Altyazı Şeridi", en="Caption Bar",
                 category="social", track="upbeat-01",
                 palette=PALETTES["charcoal"], pro=False, duration=6.5)
    t.add(bg())
    t.add(media("clip", 0, anims=[fade_in(0.5),
                                  ken_burns(6.5, zoom=1.1, direction="up")]))
    t.add(scrim("veil-top", direction="up", y=0.09, h=0.18))
    t.add(scrim("veil-bottom", direction="down", y=0.8, h=0.4))
    t.add(shape("avatar-ring", "accent", x=0.115, y=0.085, w=0.085, h=0.048,
                mask="circle", anims=[scale_in(0.7, 0.5)]))
    t.add(text("handle", "handle", "@ada.kaya", "@ada.kaya", 0.022,
               x=0.42, y=0.085, w=0.44, h=0.04, font="AvenirNext-DemiBold",
               align="left", start=0.3, anims=[slide_in("right", 0.03, 0.5)]))
    t.add(text("caption", "caption", "bu tarifi üç kez\ndenedim, sonunda tuttu",
               "made this recipe three\ntimes, finally nailed it", 0.042,
               y=0.795, w=0.78, h=0.14, font="AvenirNext-Heavy",
               role="background", highlight="surface", lines=2,
               start=0.55, anims=[pop(1.06, 0.45)]))
    t.add(text("cta", "cta", "tarif profilde", "recipe in bio", 0.021,
               y=0.905, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    return t


# 10 — Müşteri Sözü: solda dikey çubuk, sağda alıntı, altta daire foto + isim.
def testimonial_quote():
    t = Template("testimonial-quote-01", tr="Müşteri Sözü", en="Client Quote",
                 category="business", track="clean-01",
                 palette=PALETTES["ivory"], pro=False, duration=7.0)
    t.add(bg())
    t.add(text("kicker", "kicker", "MÜŞTERİ SÖZÜ", "CLIENT STORY", 0.02,
               x=0.42, y=0.215, w=0.5, h=0.035, font="AvenirNext-DemiBold",
               role="accent", align="left", caps=True, tracking=0.014,
               start=0.25, anims=[fade_in(0.5)]))
    t.add(shape("bar", "accent", x=0.115, y=0.42, w=0.008, h=0.34,
                start=0.4, anims=[wipe("down", 0.7)]))
    t.add(text("quote", "quote",
               "Ekiple çalışmak\nişimizi baştan\nkurgulamamızı\nsağladı.",
               "Working with them\nchanged how we\nrun the whole\nbusiness.", 0.042,
               x=0.56, y=0.42, w=0.72, h=0.34, font="Georgia-Bold",
               role="textPrimary", align="left", lines=4,
               start=0.55, anims=[slide_in("up", 0.03, 0.7)]))
    t.add(media("avatar", 0, x=0.155, y=0.7, w=0.16, h=0.09, kind="photo",
                mask="circle", filter="warm", intensity=0.25,
                anims=[scale_in(0.8, 0.6, delay=1.0), ken_burns(7.0, zoom=1.08)]))
    t.add(text("name", "name", "Selin Aydın", "Selin Aydin", 0.026,
               x=0.6, y=0.682, w=0.6, h=0.042, font="AvenirNext-Bold",
               role="textPrimary", align="left",
               start=1.15, anims=[fade_in(0.5)]))
    t.add(text("role", "role", "Kurucu · Nora Stüdyo", "Founder · Nora Studio", 0.019,
               x=0.6, y=0.728, w=0.6, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", align="left",
               start=1.3, anims=[fade_in(0.5)]))
    return t


# 11 — Rakam Kartı: medyasız, ortada dev rakam, arkada büyük soluk daire.
def stat_card():
    t = Template("stat-card-01", tr="Rakam Kartı", en="Stat Card",
                 category="business", track="anticipation-01",
                 palette=PALETTES["steel"], pro=True, duration=6.0)
    t.add(bg())
    t.add(shape("halo", "accent", y=0.47, w=0.78, h=0.44, mask="circle",
                opacity=0.13, anims=[scale_in(0.78, 0.9), pulse(3.2, 1.04)]))
    t.add(text("label", "label", "YILLIK BÜYÜME", "YEARLY GROWTH", 0.026,
               y=0.335, w=0.8, h=0.045, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.016,
               start=0.3, anims=[fade_in(0.5)]))
    t.add(text("figure", "figure", "%127", "127%", 0.16,
               y=0.47, w=0.9, h=0.2, font="AvenirNext-Heavy",
               role="textPrimary", tracking=-0.004,
               start=0.5, anims=[scale_in(0.7, 0.7)]))
    t.add(text("detail", "detail",
               "Son 12 ayda tekrar eden\ngelirimizi ikiye katladık.",
               "We doubled recurring\nrevenue in twelve months.", 0.022,
               y=0.635, w=0.76, h=0.08, font="AvenirNext-Regular",
               role="textSecondary", lines=2,
               start=0.95, anims=[slide_in("up", 0.03, 0.6)]))
    t.add(shape("rule", "accent", y=0.725, w=0.09, h=0.004,
                start=1.2, anims=[wipe("right", 0.5)]))
    t.add(text("brand", "brand", "NORA STÜDYO · 2026", "NORA STUDIO · 2026", 0.02,
               y=0.785, w=0.8, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.014,
               start=1.35, anims=[fade_in(0.6)]))
    return t


# 12 — Logo Açılışı: sahne 1 açılan çizgiler, sahne 2 daire maskeli logo + marka.
def logo_reveal():
    t = Template("logo-reveal-01", tr="Logo Açılışı", en="Logo Reveal",
                 category="business", track="clean-01",
                 palette=PALETTES["slate"], pro=True)

    intro = t.scene("lines", 2.6, transition="zoomIn", transition_duration=0.6)
    intro.add(bg("background", "lines-bg"))
    for i, (y, w, delay) in enumerate(((0.4, 0.62, 0.0),
                                       (0.5, 0.44, 0.18),
                                       (0.6, 0.26, 0.36))):
        intro.add(shape(f"line{i}", "accent", y=y, w=w, h=0.004,
                        anims=[wipe("right", 0.8, delay=delay)]))
    intro.add(shape("spark", "surface", x=0.5, y=0.5, w=0.03, h=0.017,
                    mask="circle", opacity=0.9, start=1.4,
                    anims=[pop(1.3, 0.5)]))

    reveal = t.scene("mark", 3.6)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    reveal.add(shape("mark-ring", "accent", y=0.4, w=0.4, h=0.225, mask="circle",
                     opacity=0.22, anims=[scale_in(0.8, 0.7), pulse(3.0, 1.04)]))
    reveal.add(media("mark-media", 0, y=0.4, w=0.34, h=0.191, kind="photo",
                     mask="circle", filter="cool", intensity=0.2,
                     anims=[scale_in(0.7, 0.7), ken_burns(3.6, zoom=1.05)]))
    reveal.add(text("brand", "brand", "NORA STÜDYO", "NORA STUDIO", 0.05,
                    y=0.585, w=0.84, h=0.085, font="AvenirNext-Heavy",
                    caps=True, tracking=0.018, start=0.5,
                    anims=[slide_in("up", 0.035, 0.6)]))
    reveal.add(shape("brand-rule", "accent", y=0.645, w=0.1, h=0.004,
                     start=0.85, anims=[wipe("right", 0.5)]))
    reveal.add(text("tagline", "tagline", "marka ve mekân tasarımı",
                    "brand and space design", 0.021,
                    y=0.7, w=0.78, h=0.04, font="AvenirNext-Medium",
                    role="textSecondary", tracking=0.008, start=1.05,
                    anims=[fade_in(0.7)]))
    return t


TEMPLATES = [
    bold_statement, soft_gradient, film_strip, mono_frame, paper_note,
    neon_sign, retro_vhs, zoom_punch, caption_bar, testimonial_quote,
    stat_card, logo_reveal,
]
