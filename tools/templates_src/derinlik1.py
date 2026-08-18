"""DERİNLİK 1 BATCH — zayıf kalan üç kategoriyi derinleştirir (15 adet).

  education  (5) — ders programı, sınav geri sayımı, günün kelimesi,
                   mini test, öğrenci çalışması
  realestate (5) — satıldı, fiyat düştü, oda oda gezi, danışman kartı,
                   yeni ilan
  music      (5) — çalma listesi, stüdyo günü, turne takvimi, kapak
                   tasarımı, sahne akşamı

Mevcut şablonların iskeletleri bilinçli olarak TEKRARLANMADI: burada
haftalık ızgara, dev geri sayım rakamı, sözlük kartı, şık kutuları,
eğik satış bandı, ikili fiyat satırı, üç sahneli oda turu, kurumsal
danışman künyesi, dikey ilan kartı, numaralı şarkı listesi, iki
sahneli stüdyo montajı, turne poster satırları, kare kapak ve eğik
sahne rozeti var.
"""

from templatelib import *   # noqa: F403


# ------------------------------------------------------------- education

# 1 — Haftalık ızgara: solda gün rozeti, sağda konu. Medyasız.
def study_plan():
    t = Template("study-plan-01", tr="Ders Programı", en="Study Plan",
                 category="education", track="calm-01",
                 palette=PALETTES["ocean"], duration=8.0)
    t.add(bg())
    t.add(text("title", "title", "DERS PROGRAMI", "STUDY PLAN", 0.056,
               y=0.135, w=0.88, h=0.09, font="AvenirNext-Heavy",
               caps=True, tracking=0.01, start=0.2,
               anims=[slide_in("down", 0.04, 0.55)]))
    t.add(text("sub", "sub", "Bu haftanın planı · günde 45 dakika",
               "This week's plan · 45 minutes a day", 0.022,
               y=0.215, w=0.84, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.4, anims=[fade_in(0.55)]))
    t.add(shape("rule", "accent", y=0.265, w=0.12, h=0.004,
                start=0.55, anims=[wipe("right", 0.55)]))

    rows = [
        ("PZT", "MON", "Matematik · Türev", "Maths · Derivatives"),
        ("SAL", "TUE", "Fizik · Optik", "Physics · Optics"),
        ("ÇAR", "WED", "Türkçe · Paragraf", "English · Essay writing"),
        ("PER", "THU", "Kimya · Mol kavramı", "Chemistry · The mole"),
        ("CUM", "FRI", "Genel deneme sınavı", "Full mock exam"),
    ]
    for i, (tr_day, en_day, tr_topic, en_topic) in enumerate(rows):
        y = 0.34 + 0.115 * i
        begin = 0.5 + 0.13 * i
        t.add(shape(f"chip{i}", "accent", x=0.165, y=y, w=0.17, h=0.085,
                    radius=0.02, start=begin, anims=[pop(1.08, 0.45)]))
        t.add(text(f"day{i}", f"day{i + 1}", tr_day, en_day, 0.028,
                   x=0.165, y=y, w=0.15, h=0.05, font="AvenirNext-Heavy",
                   role="textOnAccent", caps=True, tracking=0.008,
                   start=begin + 0.05, anims=[fade_in(0.35)]))
        t.add(text(f"topic{i}", f"topic{i + 1}", tr_topic, en_topic, 0.032,
                   x=0.60, y=y, w=0.62, h=0.065, font="AvenirNext-DemiBold",
                   align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.05, 0.5)]))
    t.add(text("footer", "footer", "Kaydet, pazartesi başla",
               "Save this and start Monday", 0.02,
               y=0.905, w=0.8, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 2 — Medyasız geri sayım: ortada dev gün sayısı.
def exam_countdown():
    t = Template("exam-countdown-01", tr="Sınava Kalan", en="Exam Countdown",
                 category="education", track="anticipation-01",
                 palette=PALETTES["punch"], pro=True, duration=6.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.44, w=0.90, h=0.50, radius=0.25,
                opacity=0.16, anims=[scale_in(0.82, 1.0), pulse(2.4, 1.05)]))
    t.add(text("kicker", "kicker", "SINAVA SON", "COUNTDOWN TO", 0.024,
               y=0.19, w=0.8, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.02,
               start=0.2, anims=[fade_in(0.55)]))
    t.add(text("exam", "exam", "YKS · 20 HAZİRAN 2026", "FINALS · JUNE 20, 2026", 0.032,
               y=0.27, w=0.88, h=0.055, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.012,
               start=0.35, anims=[slide_in("down", 0.03, 0.5)]))
    t.add(text("days", "days", "58", "58", 0.165,
               y=0.47, w=0.86, h=0.20, font="AvenirNext-Heavy",
               tracking=0.004, start=0.5, anims=[scale_in(0.78, 0.7)]))
    t.add(text("unit", "unit", "GÜN KALDI", "DAYS TO GO", 0.026,
               y=0.625, w=0.7, h=0.04, font="AvenirNext-DemiBold",
               caps=True, tracking=0.024, start=0.8, anims=[fade_in(0.5)]))
    t.add(shape("rule", "accent", y=0.685, w=0.14, h=0.005,
                start=0.95, anims=[wipe("right", 0.55)]))
    t.add(text("motto", "motto", "Bugün çözdüğün her soru\nyarının cevabı.",
               "Every question you solve today\nis tomorrow's answer.", 0.034,
               y=0.775, w=0.84, h=0.13, font="AvenirNext-Medium",
               lines=2, start=1.0, anims=[slide_in("up", 0.03, 0.6)]))
    t.add(text("footer", "footer", "Günde 30 soru · Aksatma yok",
               "30 questions a day · No excuses", 0.02,
               y=0.90, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 3 — Sözlük kartı: kelime + telaffuz + tanım + örnek, ince ayraçlar.
def word_of_day():
    t = Template("word-of-day-01", tr="Günün Kelimesi", en="Word of the Day",
                 category="education", track="typewriter-01",
                 palette=PALETTES["ivory"], duration=7.5)
    t.add(bg())
    t.add(shape("card", "surface", y=0.50, w=0.86, h=0.62, radius=0.022,
                anims=[scale_in(0.95, 0.6)]))
    t.add(text("kicker", "kicker", "GÜNÜN KELİMESİ", "WORD OF THE DAY", 0.019,
               x=0.5, y=0.235, w=0.74, h=0.035, font="AvenirNext-Medium",
               role="accent", align="left", caps=True, tracking=0.014,
               start=0.3, anims=[fade_in(0.55)]))
    t.add(text("word", "word", "münzevi", "petrichor", 0.07,
               x=0.5, y=0.31, w=0.74, h=0.10, font="Georgia-Bold",
               align="left", start=0.45, anims=[typewriter(1.0)]))
    t.add(text("pron", "pron", "/mün-ze-vî/ · sıfat", "/ˈpe-trə-kôr/ · noun", 0.022,
               x=0.5, y=0.39, w=0.74, h=0.04, font="Georgia-Italic",
               role="textSecondary", align="left",
               start=0.7, anims=[fade_in(0.55)]))
    t.add(shape("div1", "textSecondary", y=0.435, w=0.74, h=0.0018,
                opacity=0.35, start=0.8, anims=[wipe("right", 0.6)]))
    t.add(text("def-label", "defLabel", "TANIM", "MEANING", 0.018,
               x=0.5, y=0.475, w=0.74, h=0.03, font="AvenirNext-DemiBold",
               role="accent", align="left", caps=True, tracking=0.016,
               start=0.85, anims=[fade_in(0.5)]))
    t.add(text("definition", "definition",
               "Toplumdan uzak durup\nyalnız yaşamayı seçen.",
               "The earthy scent that rises\nwhen rain hits dry ground.", 0.03,
               x=0.5, y=0.55, w=0.74, h=0.10, font="AvenirNext-Medium",
               align="left", lines=2, start=0.95,
               anims=[slide_in("right", 0.03, 0.55)]))
    t.add(shape("div2", "textSecondary", y=0.625, w=0.74, h=0.0018,
                opacity=0.35, start=1.05, anims=[wipe("right", 0.6)]))
    t.add(text("ex-label", "exLabel", "ÖRNEK", "IN A SENTENCE", 0.018,
               x=0.5, y=0.665, w=0.74, h=0.03, font="AvenirNext-DemiBold",
               role="accent", align="left", caps=True, tracking=0.016,
               start=1.1, anims=[fade_in(0.5)]))
    t.add(text("example", "example",
               "“Yıllardır dağ evinde\nmünzevi bir hayat sürüyor.”",
               "“The petrichor drifted in\nthrough the open window.”", 0.026,
               x=0.5, y=0.74, w=0.74, h=0.09, font="Georgia-Italic",
               role="textSecondary", align="left", lines=2,
               start=1.15, anims=[fade_in(0.6)]))
    t.add(text("footer", "footer", "Her gün yeni bir kelime",
               "A new word every day", 0.02,
               y=0.87, w=0.8, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.008,
               start=1.2, anims=[fade_in(0.65)]))
    return t


# 4 — Mini test: soru üstte, A/B/C kutuları kademeli girer.
def quiz_card():
    t = Template("quiz-card-01", tr="Mini Test", en="Quiz Card",
                 category="education", track="playful-01",
                 palette=PALETTES["grape"], pro=True, duration=8.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.28, w=0.94, h=0.44, radius=0.22,
                opacity=0.15, anims=[scale_in(0.85, 0.95), pulse(2.8, 1.04)]))
    t.add(text("kicker", "kicker", "MİNİ TEST", "QUICK QUIZ", 0.026,
               y=0.155, w=0.8, h=0.045, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.022,
               start=0.2, anims=[slide_in("down", 0.04, 0.5)]))
    t.add(text("question", "question",
               "Güneş'e en yakın\ngezegen hangisidir?",
               "Which planet orbits\nclosest to the Sun?", 0.05,
               y=0.30, w=0.84, h=0.18, font="AvenirNext-Bold", lines=2,
               start=0.35, anims=[slide_in("up", 0.04, 0.6)]))

    options = [
        ("A", "Venüs", "Venus"),
        ("B", "Merkür", "Mercury"),
        ("C", "Mars", "Mars"),
    ]
    for i, (letter, tr_opt, en_opt) in enumerate(options):
        y = 0.52 + 0.13 * i
        begin = 0.55 + 0.22 * i
        t.add(shape(f"box{i}", "surface", y=y, w=0.80, h=0.105, radius=0.052,
                    start=begin, anims=[slide_in("up", 0.04, 0.5)]))
        t.add(text(f"letter{i}", f"option{i + 1}Letter", letter, letter, 0.034,
                   x=0.19, y=y, w=0.10, h=0.055, font="AvenirNext-Heavy",
                   role="accent", start=begin + 0.08, anims=[fade_in(0.35)]))
        t.add(text(f"option{i}", f"option{i + 1}", tr_opt, en_opt, 0.032,
                   x=0.58, y=y, w=0.58, h=0.055, font="AvenirNext-DemiBold",
                   role="background", align="left",
                   start=begin + 0.08, anims=[fade_in(0.4)]))
    t.add(text("footer", "footer", "Cevabı yorumlara yaz 👇",
               "Drop your answer in the comments 👇", 0.024,
               y=0.90, w=0.86, h=0.045, font="AvenirNext-Medium",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 5 — Tam kadraj öğrenci işi + köşe rozeti + öğrenci satırı.
def student_work():
    t = Template("student-work-01", tr="Öğrenci Çalışması", en="Student Work",
                 category="education", track="bright-01",
                 palette=PALETTES["terracotta"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.3,
                anims=[fade_in(0.6), ken_burns(6.5, zoom=1.10, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.13, h=0.26))
    t.add(scrim("scrim-bottom"))
    t.add(shape("badge", "accent", x=0.71, y=0.115, w=0.50, h=0.082,
                radius=0.041, start=0.35, anims=[slide_in("left", 0.06, 0.55)]))
    t.add(text("badge-text", "badge", "GRAFİK TASARIM KURSU", "GRAPHIC DESIGN COURSE",
               0.021, x=0.71, y=0.115, w=0.47, h=0.04, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.006,
               start=0.55, anims=[fade_in(0.4)]))
    t.add(text("headline", "headline", "Öğrenci Çalışması", "Student Work", 0.054,
               y=0.775, w=0.88, h=0.09, font="AvenirNext-Heavy",
               start=0.7, anims=[slide_in("up", 0.05, 0.6)]))
    t.add(text("student", "student", "Elif Demir · 3. dönem", "Sofia Reyes · Term 3", 0.028,
               y=0.855, w=0.86, h=0.045, font="AvenirNext-DemiBold",
               role="accent", start=0.95, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("note", "note", "Bitirme projesi · Afiş serisi",
               "Final project · Poster series", 0.021,
               y=0.915, w=0.86, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# ------------------------------------------------------------ realestate

# 6 — Tam kadraj + eğik "SATILDI" bandı + süre bilgisi.
def just_sold():
    t = Template("just-sold-01", tr="Satıldı", en="Just Sold",
                 category="realestate", track="upbeat-01",
                 palette=PALETTES["forest"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="vivid", intensity=0.3,
                anims=[fade_in(0.5), ken_burns(6.5, zoom=1.12, direction="left")]))
    t.add(scrim("scrim-top", direction="up", y=0.12, h=0.24))
    t.add(scrim("scrim-bottom"))
    t.add(text("agency", "agency", "MERİDYEN EMLAK", "MERIDIAN REALTY", 0.022,
               y=0.095, w=0.86, h=0.04, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.018,
               start=0.25, anims=[fade_in(0.55)]))
    t.add(shape("band", "accent", y=0.42, w=1.02, h=0.135, rotation=-7,
                start=0.4, anims=[wipe("right", 0.6)]))
    t.add(text("band-text", "sold", "SATILDI", "JUST SOLD", 0.085,
               y=0.42, w=0.96, h=0.14, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.02, rotation=-7,
               start=0.7, anims=[pop(1.08, 0.5)]))
    t.add(text("info", "info", "Moda, Kadıköy · 3+1 · 118 m²",
               "Riverside · 3 bed · 1,270 ft²", 0.03,
               y=0.795, w=0.88, h=0.05, font="AvenirNext-DemiBold",
               start=0.95, anims=[slide_in("up", 0.04, 0.55)]))
    t.add(text("speed", "speed", "14 günde satıldı", "Sold in 14 days", 0.046,
               y=0.865, w=0.88, h=0.07, font="AvenirNext-Heavy",
               role="accent", start=1.1, anims=[scale_in(0.88, 0.55)]))
    t.add(text("cta", "cta", "Sıradaki eviniz olabilir · DM",
               "Yours could be next · DM us", 0.02,
               y=0.94, w=0.88, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 7 — Üstte foto, altta üstü çizili eski fiyat (sol) + dev yeni fiyat (sağ).
def price_drop():
    t = Template("price-drop-01", tr="Fiyat Düştü", en="Price Drop",
                 category="realestate", track="clean-01",
                 palette=PALETTES["steel"], pro=True, duration=7.0)
    t.add(bg())
    t.add(media("photo", 0, y=0.30, w=0.96, h=0.56, kind="photo", radius=0.014,
                filter="cool", intensity=0.3,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.08, direction="down")]))
    t.add(text("kicker", "kicker", "FİYAT GÜNCELLENDİ", "PRICE JUST DROPPED", 0.024,
               y=0.622, w=0.88, h=0.04, font="AvenirNext-Heavy",
               role="accent", caps=True, tracking=0.018,
               start=0.45, anims=[wipe("right", 0.6)]))
    t.add(text("old-label", "oldLabel", "ESKİ FİYAT", "WAS", 0.018,
               x=0.30, y=0.665, w=0.40, h=0.03, font="AvenirNext-Medium",
               role="textSecondary", align="left", caps=True, tracking=0.016,
               start=0.65, anims=[fade_in(0.45)]))
    t.add(text("new-label", "newLabel", "YENİ FİYAT", "NOW", 0.018,
               x=0.72, y=0.665, w=0.40, h=0.03, font="AvenirNext-Medium",
               role="accent", align="right", caps=True, tracking=0.016,
               start=0.75, anims=[fade_in(0.45)]))
    t.add(text("old-price", "oldPrice", "4.950.000 ₺", "$389,000", 0.044,
               x=0.30, y=0.755, w=0.40, h=0.06, font="AvenirNext-DemiBold",
               role="textSecondary", align="left",
               start=0.8, anims=[fade_in(0.5)]))
    t.add(shape("strike", "textSecondary", x=0.255, y=0.755, w=0.29, h=0.004,
                start=1.0, anims=[wipe("right", 0.45)]))
    t.add(text("new-price", "newPrice", "4.350.000 ₺", "$342,000", 0.072,
               x=0.74, y=0.75, w=0.44, h=0.115, font="AvenirNext-Heavy",
               role="textPrimary", align="right",
               start=0.9, anims=[scale_in(0.85, 0.6)]))
    t.add(shape("rule", "accent", y=0.835, w=0.88, h=0.002, opacity=0.5,
                start=1.05, anims=[wipe("left", 0.6)]))
    t.add(text("info", "info", "3+1 · 128 m² · Ataşehir · 5. kat",
               "3 bed · 1,378 ft² · Riverside · 5th floor", 0.024,
               y=0.878, w=0.9, h=0.045, font="AvenirNext-Medium",
               start=1.1, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("cta", "cta", "Fırsat için arayın · 0532 000 00 00",
               "Call today · 555 010 0134", 0.02,
               y=0.94, w=0.9, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 8 — Montaj: üç oda, her sahnede oda etiketi, slideLeft geçiş.
def room_tour():
    t = Template("room-tour-01", tr="Oda Oda Gezi", en="Room Tour",
                 category="realestate", track="smooth-01",
                 palette=PALETTES["slate"], pro=True)
    rooms = [
        (2.6, "01", "SALON", "LIVING ROOM", "32 m² · güneybatı cephe",
         "344 ft² · south-west facing"),
        (2.6, "02", "MUTFAK", "KITCHEN", "Ada tezgâh · ankastre set",
         "Island counter · fitted appliances"),
        (2.8, "03", "YATAK ODASI", "BEDROOM", "Tamamını görmek için DM",
         "DM us for the full tour"),
    ]
    for i, (dur, num, tr_name, en_name, tr_note, en_note) in enumerate(rooms):
        last = i == len(rooms) - 1
        s = t.scene(f"room{i}", dur,
                    transition=None if last else "slideLeft",
                    transition_duration=0.4)
        # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
        # compositor paletteki background'ı zaten boyar.
        s.add(media(f"r{i}-media", i, filter="cool", intensity=0.25,
                    anims=[fade_in(0.4),
                           ken_burns(dur, zoom=1.09,
                                     direction="up" if i % 2 == 0 else "right")]))
        s.add(scrim(f"r{i}-scrim-top", direction="up", y=0.11, h=0.22))
        s.add(scrim(f"r{i}-scrim", direction="down", y=0.80, h=0.40))
        s.add(shape(f"r{i}-chip", "accent", x=0.155, y=0.135, w=0.17, h=0.068,
                    radius=0.012, anims=[scale_in(0.75, 0.4)]))
        s.add(text(f"r{i}-num", "roomNumber", num, num, 0.028,
                   x=0.155, y=0.135, w=0.15, h=0.045, font="Archivo-SemiBold",
                   role="background", start=0.15, anims=[fade_in(0.35)]))
        s.add(text(f"r{i}-tour", "tourLabel", "ODA ODA GEZİ", "ROOM TOUR", 0.022,
                   x=0.72, y=0.135, w=0.44, h=0.04, font="AvenirNext-Medium",
                   align="right", caps=True, tracking=0.014,
                   start=0.2, anims=[fade_in(0.4)]))
        s.add(text(f"r{i}-name", "roomName", tr_name, en_name, 0.058,
                   y=0.845, w=0.88, h=0.10, font="AvenirNext-Heavy",
                   caps=True, tracking=0.01,
                   start=0.3, anims=[slide_in("up", 0.05, 0.5)]))
        s.add(text(f"r{i}-note", "roomNote", tr_note, en_note, 0.023,
                   y=0.92, w=0.86, h=0.04, font="AvenirNext-Regular",
                   role="textSecondary", start=0.5, anims=[fade_in(0.5)]))
    return t


# 9 — Kurumsal danışman kartı: daire portre + künye satırları.
def agent_card():
    t = Template("agent-card-01", tr="Danışman Kartı", en="Agent Card",
                 category="realestate", track="clean-01",
                 palette=PALETTES["ivory"], duration=7.0)
    t.add(bg())
    t.add(shape("header", "accent", y=0.055, w=1.0, h=0.11,
                anims=[slide_in("down", 0.05, 0.5)]))
    t.add(text("brand", "brand", "MERİDYEN EMLAK", "MERIDIAN REALTY", 0.024,
               y=0.055, w=0.86, h=0.045, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.024,
               start=0.3, anims=[fade_in(0.5)]))
    t.add(shape("ring", "accent", y=0.31, w=0.55, h=0.3094, mask="circle",
                opacity=0.9, start=0.25, anims=[scale_in(0.86, 0.6)]))
    t.add(media("portrait", 0, y=0.31, w=0.52, h=0.2925, kind="photo",
                mask="circle", filter="warm", intensity=0.2,
                anims=[scale_in(0.9, 0.65), ken_burns(7.0, zoom=1.07, direction="up")]))
    t.add(text("name", "name", "Elif Demir", "Claire Bennett", 0.058,
               y=0.51, w=0.86, h=0.09, font="AvenirNext-Bold",
               start=0.6, anims=[slide_in("up", 0.03, 0.55)]))
    t.add(text("role", "role", "GAYRİMENKUL DANIŞMANI", "REAL ESTATE ADVISOR", 0.02,
               y=0.578, w=0.82, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.018,
               start=0.75, anims=[fade_in(0.5)]))
    t.add(shape("rule", "accent", y=0.635, w=0.10, h=0.004,
                start=0.85, anims=[wipe("right", 0.5)]))

    rows = [
        ("TELEFON", "PHONE", "0532 000 00 00", "555 010 0134"),
        ("OFİS", "OFFICE", "Bağdat Cad. No:212, Kadıköy", "212 Maple Avenue, Riverside"),
        ("E-POSTA", "EMAIL", "elif@meridyenemlak.com", "claire@meridianrealty.com"),
    ]
    for i, (tr_label, en_label, tr_value, en_value) in enumerate(rows):
        y = 0.70 + 0.085 * i
        begin = 0.9 + 0.13 * i
        t.add(text(f"label{i}", f"row{i + 1}Label", tr_label, en_label, 0.017,
                   x=0.30, y=y, w=0.44, h=0.028, font="AvenirNext-Medium",
                   role="textSecondary", align="left", caps=True, tracking=0.016,
                   start=begin, anims=[fade_in(0.45)]))
        t.add(text(f"value{i}", f"row{i + 1}", tr_value, en_value, 0.024,
                   x=0.70, y=y, w=0.44, h=0.045, font="AvenirNext-DemiBold",
                   align="right", start=begin + 0.05,
                   anims=[slide_in("left", 0.02, 0.45)]))
        if i < len(rows) - 1:
            t.add(shape(f"sep{i}", "textSecondary", y=y + 0.0425, w=0.84,
                        h=0.0015, opacity=0.3, start=begin + 0.1,
                        anims=[wipe("right", 0.5)]))
    t.add(text("footer", "footer", "Ücretsiz değerleme için arayın",
               "Free valuation — just call", 0.02,
               y=0.945, w=0.84, h=0.035, font="AvenirNext-DemiBold",
               role="accent", start=1.2, anims=[fade_in(0.6)]))
    return t


# 10 — Dikey ilan kartı: foto + üç sütun künye + DM satırı.
def new_listing():
    t = Template("new-listing-01", tr="Yeni İlan", en="New Listing",
                 category="realestate", track="bright-01",
                 palette=PALETTES["paper"], duration=7.0)
    t.add(bg())
    t.add(shape("card", "surface", y=0.50, w=0.88, h=0.82, radius=0.024,
                anims=[scale_in(0.94, 0.6)]))
    t.add(shape("tag", "accent", x=0.255, y=0.155, w=0.28, h=0.062,
                radius=0.031, start=0.3, anims=[pop(1.1, 0.5)]))
    t.add(text("tag-text", "tag", "YENİ İLAN", "NEW LISTING", 0.022,
               x=0.255, y=0.155, w=0.26, h=0.04, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.008,
               start=0.45, anims=[fade_in(0.4)]))
    t.add(media("photo", 0, y=0.38, w=0.78, h=0.36, kind="photo", radius=0.014,
                filter="warm", intensity=0.25,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.08, direction="left")]))
    t.add(text("title", "title", "Deniz Manzaralı 3+1", "Sea-View 3 Bedroom", 0.048,
               y=0.625, w=0.80, h=0.075, font="Georgia-Bold",
               start=0.65, anims=[slide_in("up", 0.03, 0.55)]))
    t.add(text("place", "place", "Karşıyaka, İzmir · site içinde",
               "Lakeview, Denver · gated complex", 0.022,
               y=0.69, w=0.78, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.85, anims=[fade_in(0.55)]))
    t.add(shape("divider", "textSecondary", y=0.735, w=0.76, h=0.0018,
                opacity=0.35, start=0.95, anims=[wipe("right", 0.6)]))

    cols = [
        (0.24, "ODA", "ROOMS", "3+1", "3 bed"),
        (0.50, "ALAN", "AREA", "135 m²", "1,453 ft²"),
        (0.76, "KAT", "FLOOR", "6 / 12", "6 of 12"),
    ]
    for i, (x, tr_label, en_label, tr_value, en_value) in enumerate(cols):
        begin = 1.0 + 0.12 * i
        t.add(text(f"clabel{i}", f"spec{i + 1}Label", tr_label, en_label, 0.017,
                   x=x, y=0.775, w=0.24, h=0.028, font="AvenirNext-Medium",
                   role="textSecondary", caps=True, tracking=0.016,
                   start=begin, anims=[fade_in(0.45)]))
        t.add(text(f"cvalue{i}", f"spec{i + 1}", tr_value, en_value, 0.034,
                   x=x, y=0.828, w=0.24, h=0.06, font="AvenirNext-Heavy",
                   start=begin + 0.05, anims=[slide_in("up", 0.025, 0.45)]))
    t.add(shape("cdiv1", "textSecondary", x=0.37, y=0.805, w=0.0018, h=0.08,
                opacity=0.3, start=1.1, anims=[fade_in(0.4)]))
    t.add(shape("cdiv2", "textSecondary", x=0.63, y=0.805, w=0.0018, h=0.08,
                opacity=0.3, start=1.15, anims=[fade_in(0.4)]))
    t.add(text("cta", "cta", "Detay için DM gönderin", "DM us for details", 0.026,
               y=0.885, w=0.78, h=0.045, font="AvenirNext-Bold",
               role="accent", start=1.2, anims=[fade_in(0.6)]))
    return t


# ----------------------------------------------------------------- music

# 11 — Çalma listesi: kare kapak + numaralı dört şarkı satırı.
def playlist_card():
    t = Template("playlist-card-01", tr="Çalma Listesi", en="Playlist",
                 category="music", track="chill-01",
                 palette=PALETTES["midnight"], duration=8.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.28, w=0.92, h=0.42, mask="circle",
                opacity=0.10, anims=[scale_in(0.85, 0.9), pulse(3.0, 1.04)]))
    t.add(text("kicker", "kicker", "ÇALMA LİSTESİ", "PLAYLIST", 0.022,
               y=0.115, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.024,
               start=0.25, anims=[fade_in(0.55)]))
    t.add(media("cover", 0, y=0.29, w=0.44, h=0.2475, kind="photo", radius=0.012,
                filter="cool", intensity=0.35,
                anims=[scale_in(0.88, 0.65), ken_burns(8.0, zoom=1.06, direction="up")]))
    t.add(text("name", "name", "Gece Sürüşü", "Night Drive", 0.062,
               y=0.47, w=0.88, h=0.10, font="AvenirNext-Heavy",
               start=0.55, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("meta", "meta", "12 şarkı · 41 dakika", "12 tracks · 41 minutes", 0.021,
               y=0.545, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.75, anims=[fade_in(0.55)]))

    songs = [
        ("1", "Gece Yarısı — Mert Kaya", "Midnight Hour — Miles Carter", "3:42"),
        ("2", "Sahil Yolu — Deniz Ay", "Coast Road — Ava Lane", "4:05"),
        ("3", "Uzak — Kara Orman", "Faraway — Dark Pines", "3:18"),
        ("4", "Son Durak — Ela", "Last Stop — Elle Ray", "2:57"),
    ]
    for i, (num, tr_song, en_song, length) in enumerate(songs):
        y = 0.645 + 0.083 * i
        begin = 0.85 + 0.09 * i
        t.add(text(f"num{i}", f"track{i + 1}Num", num, num, 0.026,
                   x=0.13, y=y, w=0.10, h=0.05, font="AvenirNext-Heavy",
                   role="accent", align="left",
                   start=begin, anims=[fade_in(0.4)]))
        t.add(text(f"song{i}", f"track{i + 1}", tr_song, en_song, 0.028,
                   x=0.50, y=y, w=0.56, h=0.05, font="AvenirNext-Medium",
                   align="left", start=begin + 0.05,
                   anims=[slide_in("right", 0.04, 0.45)]))
        t.add(text(f"len{i}", f"track{i + 1}Len", length, length, 0.021,
                   x=0.88, y=y, w=0.16, h=0.04, font="AvenirNext-Regular",
                   role="textSecondary", align="right",
                   start=begin + 0.1, anims=[fade_in(0.4)]))
    t.add(text("footer", "footer", "Profildeki bağlantıda", "Link in bio", 0.019,
               y=0.955, w=0.7, h=0.03, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 12 — Montaj: stüdyo kadrajı → kapanış tipografisi, crossDissolve.
def studio_session():
    t = Template("studio-session-01", tr="Stüdyo Günü", en="Studio Session",
                 category="music", track="groovy-01",
                 palette=PALETTES["charcoal"], pro=True)

    booth = t.scene("booth", 4.0, transition="crossDissolve", transition_duration=0.6)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    booth.add(media("booth-media", 0, filter="mono", intensity=0.35,
                    anims=[fade_in(0.5), ken_burns(4.0, zoom=1.10, direction="down")]))
    booth.add(scrim("booth-scrim-top", direction="up", y=0.12, h=0.24))
    booth.add(scrim("booth-scrim", direction="down", y=0.78, h=0.44))
    booth.add(text("booth-kicker", "kicker", "STÜDYO GÜNÜ", "STUDIO SESSION", 0.026,
                   y=0.11, w=0.84, h=0.045, font="AvenirNext-DemiBold",
                   role="accent", caps=True, tracking=0.022,
                   start=0.25, anims=[fade_in(0.55)]))
    bars = [0.030, 0.048, 0.036, 0.055, 0.028, 0.050, 0.038, 0.044, 0.032]
    for i, bh in enumerate(bars):
        booth.add(shape(f"bar{i}", "accent", x=0.34 + 0.04 * i, y=0.695,
                        w=0.012, h=bh, radius=0.006,
                        start=0.5 + 0.05 * i,
                        anims=[scale_in(0.4, 0.35),
                               pulse(0.65 + 0.08 * i, 1.6, axis="y")]))
    booth.add(text("booth-title", "sessionTitle", "Yeni albüm\nkayıtta",
                   "New album\nin the making", 0.055,
                   y=0.815, w=0.86, h=0.14, font="AvenirNext-Heavy", lines=2,
                   start=0.7, anims=[slide_in("up", 0.05, 0.6)]))
    booth.add(text("booth-note", "sessionNote", "3. gün · altı parça bitti",
                   "Day three · six tracks down", 0.022,
                   y=0.94, w=0.82, h=0.035, font="AvenirNext-Regular",
                   role="textSecondary", start=1.0, anims=[fade_in(0.6)]))

    closing = t.scene("closing", 3.4)
    closing.add(bg("background", "closing-bg"))
    closing.add(shape("disc", "accent", y=0.34, w=0.32, h=0.18, mask="circle",
                      opacity=0.9, anims=[scale_in(0.7, 0.6), pulse(2.4, 1.05)]))
    closing.add(sticker("headphones", "headphones", "🎧", size=0.075, y=0.34,
                        start=0.25, anims=[bounce(0.7)]))
    closing.add(text("closing-line", "closingLine", "Kayıt bitti.\nSıra sizde.",
                     "Recording done.\nYour turn next.", 0.056,
                     y=0.55, w=0.84, h=0.16, font="AvenirNext-Bold", lines=2,
                     start=0.4, anims=[slide_in("up", 0.04, 0.6)]))
    closing.add(shape("closing-rule", "accent", y=0.665, w=0.12, h=0.004,
                      start=0.75, anims=[wipe("right", 0.5)]))
    closing.add(text("closing-date", "closingDate", "Albüm 14 Kasım'da",
                     "Album out November 14", 0.028,
                     y=0.73, w=0.82, h=0.05, font="AvenirNext-Heavy",
                     role="accent", start=0.85, anims=[fade_in(0.55)]))
    closing.add(text("closing-handle", "closingHandle", "@mertkaya.music",
                     "@milescarter.music", 0.02,
                     y=0.80, w=0.7, h=0.035, font="AvenirNext-Regular",
                     role="textSecondary", tracking=0.008,
                     start=1.05, anims=[fade_in(0.6)]))
    return t


# 13 — Medyasız turne posteri: dört tarih/şehir satırı, ince ayraçlar.
def tour_dates():
    t = Template("tour-dates-01", tr="Turne Takvimi", en="Tour Dates",
                 category="music", track="punchy-01",
                 palette=PALETTES["retro"], pro=True, duration=8.0)
    t.add(bg())
    t.add(text("band", "band", "KUZEY YOLU", "NORTHBOUND", 0.026,
               y=0.115, w=0.86, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.028,
               start=0.2, anims=[fade_in(0.55)]))
    t.add(text("title", "title", "TURNE 2026", "TOUR 2026", 0.082,
               y=0.205, w=0.92, h=0.13, font="AvenirNext-Heavy",
               caps=True, tracking=0.012, start=0.3,
               anims=[slide_in("down", 0.04, 0.6)]))
    t.add(shape("rule-top", "accent", y=0.29, w=0.88, h=0.005,
                start=0.55, anims=[wipe("right", 0.65)]))

    dates = [
        ("14 EKİM", "OCT 14", "İSTANBUL", "AUSTIN"),
        ("21 EKİM", "OCT 21", "ANKARA", "DENVER"),
        ("28 EKİM", "OCT 28", "İZMİR", "PORTLAND"),
        ("4 KASIM", "NOV 4", "BURSA", "NASHVILLE"),
    ]
    for i, (tr_date, en_date, tr_city, en_city) in enumerate(dates):
        y = 0.40 + 0.115 * i
        begin = 0.65 + 0.14 * i
        t.add(text(f"date{i}", f"stop{i + 1}Date", tr_date, en_date, 0.03,
                   x=0.30, y=y, w=0.44, h=0.05, font="Archivo-SemiBold",
                   role="textSecondary", align="left", caps=True, tracking=0.01,
                   start=begin, anims=[fade_in(0.45)]))
        t.add(text(f"city{i}", f"stop{i + 1}City", tr_city, en_city, 0.036,
                   x=0.70, y=y, w=0.44, h=0.055, font="AvenirNext-Heavy",
                   align="right", caps=True, tracking=0.008,
                   start=begin + 0.05, anims=[slide_in("left", 0.03, 0.45)]))
        t.add(shape(f"line{i}", "textSecondary", y=y + 0.055, w=0.88, h=0.0018,
                    opacity=0.4, start=begin + 0.1, anims=[wipe("right", 0.5)]))
    t.add(shape("ticket-chip", "accent", y=0.885, w=0.80, h=0.085, radius=0.0425,
                start=1.15, anims=[pop(1.07, 0.55)]))
    t.add(text("ticket", "ticket", "BİLETLER SATIŞTA", "TICKETS ON SALE", 0.028,
               y=0.885, w=0.76, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.012,
               start=1.2, anims=[fade_in(0.45)]))
    t.add(text("note", "note", "biletsatis.com/kuzeyyolu", "tickets.com/northbound", 0.019,
               y=0.955, w=0.8, h=0.03, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 14 — Kare albüm kapağı ortada, üstte sanatçı, altta albüm ve çıkış tarihi.
def cover_art():
    t = Template("cover-art-01", tr="Kapak Tasarımı", en="Cover Art",
                 category="music", track="beat-01",
                 palette=PALETTES["punch"], duration=7.0)
    t.add(bg())
    t.add(text("kicker", "kicker", "YENİ ALBÜM", "NEW ALBUM", 0.022,
               y=0.095, w=0.8, h=0.04, font="AvenirNext-Medium",
               role="accent", caps=True, tracking=0.026,
               start=0.2, anims=[fade_in(0.55)]))
    t.add(text("artist", "artist", "SELİN ARAS", "NORA VANCE", 0.056,
               y=0.17, w=0.88, h=0.09, font="AvenirNext-Heavy",
               caps=True, tracking=0.014, start=0.35,
               anims=[slide_in("down", 0.04, 0.55)]))
    t.add(shape("frame", "accent", y=0.46, w=0.755, h=0.4275, radius=0.01,
                opacity=0.8, start=0.45, anims=[scale_in(0.9, 0.6)]))
    t.add(media("cover", 0, y=0.46, w=0.72, h=0.405, kind="photo", radius=0.008,
                filter="vivid", intensity=0.5,
                anims=[scale_in(0.9, 0.65), ken_burns(7.0, zoom=1.07, direction="down")]))
    t.add(text("album", "album", "Kırık Radyo", "Broken Radio", 0.062,
               y=0.735, w=0.88, h=0.11, font="AvenirNext-Heavy",
               start=0.75, anims=[slide_in("up", 0.04, 0.6)]))
    t.add(text("release", "release", "9 Ekim'de her yerde", "Out everywhere October 9",
               0.028, y=0.83, w=0.84, h=0.045, font="AvenirNext-DemiBold",
               role="accent", start=0.95, anims=[fade_in(0.55)]))
    t.add(shape("rule", "accent", y=0.878, w=0.10, h=0.004,
                start=1.1, anims=[wipe("right", 0.5)]))
    t.add(text("footer", "footer", "10 şarkı · 38 dakika", "10 tracks · 38 minutes",
               0.02, y=0.925, w=0.8, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.008,
               start=1.2, anims=[fade_in(0.6)]))
    return t


# 15 — Tam kadraj mekân fotosu + eğik "SAHNE AÇIK" rozeti + gün/saat/mekân.
def open_mic():
    t = Template("open-mic-01", tr="Sahne Akşamı", en="Open Mic",
                 category="music", track="acoustic-01",
                 palette=PALETTES["honey"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.45,
                anims=[fade_in(0.5), ken_burns(6.5, zoom=1.13, direction="up")]))
    t.add(scrim("scrim-top", direction="up", y=0.16, h=0.32))
    t.add(scrim("scrim-bottom"))
    t.add(shape("badge", "accent", x=0.70, y=0.20, w=0.50, h=0.11, radius=0.055,
                rotation=-8, start=0.4, anims=[bounce(0.65)]))
    t.add(text("badge-text", "badge", "SAHNE AÇIK", "OPEN MIC", 0.032,
               x=0.70, y=0.20, w=0.46, h=0.06, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.012, rotation=-8,
               start=0.6, anims=[fade_in(0.4)]))
    t.add(text("headline", "headline", "Sahne Akşamı", "Open Mic Night", 0.06,
               y=0.735, w=0.88, h=0.10, font="AvenirNext-Heavy",
               start=0.7, anims=[slide_in("up", 0.05, 0.6)]))
    t.add(text("when", "when", "Salı 20:30 · Kadıköy", "Tuesdays 8:30 PM · Riverside", 0.03,
               y=0.82, w=0.88, h=0.05, font="AvenirNext-DemiBold",
               role="accent", start=0.95, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("venue", "venue", "Mikrofon Kahve · Moda Cad. No:41",
               "Corner Coffee · 41 Maple Ave", 0.022,
               y=0.882, w=0.9, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    t.add(text("cta", "cta", "Sıra almak için DM · Giriş serbest",
               "DM to grab a slot · Free entry", 0.02,
               y=0.94, w=0.9, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


TEMPLATES = [
    study_plan, exam_countdown, word_of_day, quiz_card, student_work,
    just_sold, price_drop, room_tour, agent_card, new_listing,
    playlist_card, studio_session, tour_dates, cover_art, open_mic,
]
