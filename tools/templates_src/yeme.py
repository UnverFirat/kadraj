"""YEME & PROMO BATCH — kafe/restoran (food) ve kampanya (promo) şablonları.

14 şablon: 8 food + 6 promo. Her biri farklı bir düzen ailesinden gelir —
menü kartı, tam kadraj, daire vitrin, montaj, numaralı adımlar, saf tipografi,
ikiye bölünmüş kadraj, bilet/kupon, dikey ürün kartı.
"""

from templatelib import *   # noqa: F403


# ------------------------------------------------------------------- food

# 1 — Menü kartı: üstte foto şeridi, altta sola/sağa yaslı üç satır.
def cafe_menu():
    t = Template("cafe-menu-01", tr="Kafe Menüsü", en="Cafe Menu",
                 category="food", pro=False, track="warm-01",
                 palette=PALETTES["cream"], duration=7.0)
    t.color("rule", "#E4D7C4")
    t.add(bg())
    t.add(media("strip", 0, y=0.155, w=0.86, h=0.26, radius=0.014,
                filter="warm", intensity=0.45,
                anims=[fade_in(0.6), ken_burns(7.0, zoom=1.10, direction="left")]))
    t.add(text("title", "title", "Bugünün Menüsü", "Today's Menu", 0.055,
               y=0.355, w=0.86, h=0.075, font="Georgia-Bold",
               role="textPrimary", start=0.35,
               anims=[slide_in("up", 0.03, 0.6)]))
    t.add(shape("title-rule", "accent", y=0.408, w=0.10, h=0.004,
                start=0.6, anims=[wipe("right", 0.5)]))
    t.add(shape("panel", "surface", y=0.655, w=0.86, h=0.46, radius=0.022,
                start=0.45, anims=[scale_in(0.95, 0.55)]))

    # Fiyat çift dilli: TR vitrininde ₺, EN vitrininde $ görünür.
    rows = [
        ("Filtre Kahve", "Filter Coffee", "₺75", "$4"),
        ("Tereyağlı Kruvasan", "Butter Croissant", "₺95", "$6"),
        ("Ev Yapımı Limonata", "House Lemonade", "₺65", "$5"),
    ]
    for i, (tr_name, en_name, tr_price, en_price) in enumerate(rows):
        y = 0.49 + 0.125 * i
        t.add(text(f"row{i}-name", f"row{i}Name", tr_name, en_name, 0.030,
                   x=0.32, y=y, w=0.42, h=0.055, font="AvenirNext-DemiBold",
                   role="textPrimary", align="left", start=0.7 + 0.15 * i,
                   anims=[slide_in("right", 0.03, 0.5)]))
        t.add(text(f"row{i}-price", f"row{i}Price", tr_price, en_price, 0.030,
                   x=0.79, y=y, w=0.18, h=0.055, font="AvenirNext-Heavy",
                   role="accent", align="right", start=0.8 + 0.15 * i,
                   anims=[fade_in(0.45)]))
        if i < 2:
            t.add(shape(f"row{i}-rule", "rule", y=y + 0.0625, w=0.70, h=0.0025,
                        start=0.95 + 0.15 * i, anims=[wipe("right", 0.45)]))

    t.add(text("note", "note", "Fiyatlara KDV dahildir", "Tax included", 0.019,
               y=0.832, w=0.7, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 2 — Tam kadraj yemek fotosu, eğik rozet, altta ad + fiyat.
def daily_special():
    t = Template("daily-special-01", tr="Günün Yemeği", en="Daily Special",
                 category="food", pro=False, track="acoustic-01",
                 palette=PALETTES["terracotta"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="warm", intensity=0.55,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.14, direction="up")]))
    t.add(scrim("scrim-bottom", direction="down", y=0.75, h=0.5))
    t.add(shape("badge", "accent", x=0.27, y=0.175, w=0.38, h=0.10,
                radius=0.05, rotation=-9, start=0.3,
                anims=[bounce(0.7)]))
    t.add(text("badge-text", "badge", "GÜNÜN", "TODAY'S", 0.034,
               x=0.27, y=0.175, w=0.34, h=0.06, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.01, rotation=-9,
               start=0.45, anims=[fade_in(0.4)]))
    t.add(text("dish", "dish", "Fırın Kuzu Tandır", "Slow-Roast Lamb", 0.062,
               y=0.785, w=0.86, h=0.09, font="AvenirNext-Heavy",
               role="textPrimary", start=0.7,
               anims=[slide_in("up", 0.05, 0.6)]))
    t.add(text("price", "price", "₺289 — pilav ve salata ile",
               "$34 — rice and salad included", 0.026,
               y=0.87, w=0.84, h=0.05, font="AvenirNext-Medium",
               role="accent", start=0.95, anims=[fade_in(0.55)]))
    t.add(text("hours", "hours", "Akşam 19:00'a kadar", "Until 7 pm", 0.020,
               y=0.935, w=0.7, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 3 — Daire vitrin: halka içinde maskeli foto, altta serif başlık.
def coffee_shop():
    t = Template("coffee-shop-01", tr="Kahve Molası", en="Coffee Break",
                 category="food", pro=True, track="chill-01",
                 palette=PALETTES["sand"], duration=6.5)
    t.add(bg())
    t.add(shape("halo", "accent", y=0.40, w=0.82, h=0.461, mask="circle",
                opacity=0.20, anims=[scale_in(0.86, 0.8), pulse(2.6, 1.03)]))
    t.add(shape("ring", "accent", y=0.40, w=0.70, h=0.394, mask="circle",
                anims=[scale_in(0.90, 0.65)]))
    t.add(media("photo", 0, y=0.40, w=0.664, h=0.374, mask="circle",
                filter="warm", intensity=0.5,
                anims=[scale_in(0.92, 0.7),
                       ken_burns(6.5, zoom=1.10, direction="right")]))
    t.add(text("kicker", "kicker", "EL YAPIMI", "SMALL BATCH", 0.024,
               y=0.115, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.012, start=0.35,
               anims=[fade_in(0.6)]))
    t.add(text("title", "title", "Kahve Molası", "Coffee Break", 0.062,
               y=0.685, w=0.84, h=0.09, font="Didot",
               role="textPrimary", start=0.6,
               anims=[slide_in("up", 0.035, 0.7)]))
    t.add(text("sub", "sub", "Her fincan günlük çekiliyor",
               "Ground fresh every morning", 0.022,
               y=0.765, w=0.78, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=0.9, anims=[fade_in(0.6)]))
    t.add(shape("dash", "accent", y=0.825, w=0.08, h=0.004,
                start=1.05, anims=[wipe("right", 0.5)]))
    t.add(text("hours", "hours", "Her gün 08:00 – 20:00", "Open daily 8 – 8", 0.021,
               y=0.885, w=0.76, h=0.04, font="AvenirNext-Medium",
               role="textPrimary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 4 — Montaj: kapalı kadrajdan geniş kadraja zoomOut, sonda tatlının adı.
def dessert_reveal():
    t = Template("dessert-reveal-01", tr="Tatlı Vitrin", en="Dessert Reveal",
                 category="food", pro=False, track="sweet-01",
                 palette=PALETTES["blush"])

    close = t.scene("close", 3.0, transition="zoomOut", transition_duration=0.5)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    close.add(media("close-media", 0, filter="warm", intensity=0.4,
                    anims=[fade_in(0.5), ken_burns(3.0, zoom=1.22, direction="down")]))
    close.add(scrim("close-scrim", direction="up", y=0.24, h=0.48))
    close.add(text("tease", "tease", "AZ SONRA…", "COMING UP…", 0.034,
                   y=0.20, w=0.8, h=0.06, font="AvenirNext-DemiBold",
                   role="textPrimary", caps=True, tracking=0.014,
                   start=0.3, anims=[fade_in(0.6)]))
    close.add(sticker("cake", "cake", "🍰", size=0.075, x=0.5, y=0.50,
                      rotation=-8, start=0.9, anims=[pop(1.15, 0.5)]))

    wide = t.scene("wide", 3.4)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    wide.add(media("wide-media", 1, kind="photo", filter="vivid", intensity=0.35,
                   anims=[ken_burns(3.4, zoom=1.06, direction="up")]))
    wide.add(scrim("wide-scrim", direction="down", y=0.76, h=0.48))
    wide.add(text("name", "name", "Frambuazlı Cheesecake", "Raspberry Cheesecake",
                  0.052, y=0.795, w=0.86, h=0.08, font="Georgia-Bold",
                  role="textPrimary", start=0.35,
                  anims=[slide_in("up", 0.04, 0.6)]))
    wide.add(text("price", "price", "Dilimi ₺135", "$16 a slice", 0.026,
                  y=0.875, w=0.7, h=0.045, font="AvenirNext-Medium",
                  role="accent", start=0.65, anims=[fade_in(0.5)]))
    wide.add(text("note", "note", "Her gün taze yapılır", "Baked fresh daily", 0.019,
                  y=0.935, w=0.7, h=0.035, font="AvenirNext-Regular",
                  role="textSecondary", start=0.95, anims=[fade_in(0.55)]))
    return t


# 5 — Paket servis: üstte duyuru şeridi, altta telefon + teslimat rozeti.
def food_delivery():
    t = Template("food-delivery-01", tr="Paket Servis", en="Delivery",
                 category="food", pro=True, track="upbeat-01",
                 palette=PALETTES["honey"], duration=6.5)
    t.add(bg())
    t.add(media("photo", 0, filter="vivid", intensity=0.45,
                anims=[fade_in(0.5), ken_burns(6.5, zoom=1.12, direction="down")]))
    t.add(scrim("scrim-top", direction="up", y=0.16, h=0.34))
    t.add(scrim("scrim-bottom", direction="down", y=0.79, h=0.42))
    t.add(shape("banner", "accent", y=0.10, w=1.0, h=0.085,
                anims=[slide_in("down", 0.09, 0.55)]))
    t.add(text("banner-text", "banner", "PAKET SERVİS VAR", "WE DELIVER", 0.032,
               y=0.10, w=0.92, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.014,
               start=0.35, anims=[fade_in(0.4)]))
    t.add(text("brand", "brand", "Lezzet Mutfağı", "Harvest Kitchen", 0.024,
               y=0.70, w=0.8, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=0.6, anims=[fade_in(0.55)]))
    t.add(text("phone", "phone", "0212 555 04 20", "(212) 555 0420", 0.052,
               y=0.785, w=0.86, h=0.085, font="AvenirNext-Heavy",
               role="textPrimary", tracking=0.006, start=0.8,
               anims=[slide_in("up", 0.04, 0.6)]))
    t.add(shape("eta", "accent", y=0.885, w=0.58, h=0.078, radius=0.039,
                start=1.0, anims=[pop(1.08, 0.5)]))
    t.add(text("eta-text", "eta", "30 dakikada kapında", "At your door in 30 min",
               0.028, y=0.885, w=0.55, h=0.05, font="AvenirNext-Bold",
               role="textOnAccent", start=1.15, anims=[fade_in(0.4)]))
    return t


# 6 — Üç sahneli mekân turu, her sahnede kısa etiket, crossDissolve.
def restaurant_tour():
    t = Template("restaurant-tour-01", tr="Mekân Turu", en="Venue Tour",
                 category="food", pro=True, track="smooth-01",
                 palette=PALETTES["ivory"])

    steps = [
        ("door", 2.2, "GİRİŞ", "THE DOOR", "Kapıdan girer girmez", "The moment you step in"),
        ("table", 2.2, "MASANIZ", "YOUR TABLE", "Pencere kenarı sizin", "The window seat is yours"),
        ("plate", 2.4, "TABAKTA", "ON THE PLATE", "Mutfaktan sıcak sıcak", "Straight from the kitchen"),
    ]
    for i, (sid, dur, tr_tag, en_tag, tr_sub, en_sub) in enumerate(steps):
        last = i == len(steps) - 1
        s = t.scene(sid, dur,
                    transition=None if last else "crossDissolve",
                    transition_duration=0.4)
        # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
        # compositor paletteki background'ı zaten boyar.
        s.add(media(f"{sid}-media", i, filter="fade", intensity=0.3,
                    kind="photoOrVideo" if i == 0 else "photo",
                    anims=[ken_burns(dur, zoom=1.09,
                                     direction=["up", "left", "down"][i])]))
        s.add(scrim(f"{sid}-scrim", direction="down", y=0.78, h=0.44))
        s.add(shape(f"{sid}-rule", "accent", y=0.735, w=0.09, h=0.004,
                    start=0.2, anims=[wipe("right", 0.45)]))
        s.add(text(f"{sid}-tag", f"{sid}Tag", tr_tag, en_tag, 0.030,
                   y=0.785, w=0.8, h=0.05, font="AvenirNext-DemiBold",
                   role="accent", caps=True, tracking=0.014, start=0.3,
                   anims=[slide_in("up", 0.03, 0.5)]))
        s.add(text(f"{sid}-sub", f"{sid}Sub", tr_sub, en_sub, 0.044,
                   y=0.858, w=0.84, h=0.07, font="Didot",
                   role="textPrimary", start=0.5,
                   anims=[fade_in(0.6)]))

    t.add(text("venue", "venue", "Lezzet Mutfağı — Moda", "Harvest Kitchen — Riverside",
               0.019, y=0.945, w=0.8, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", tracking=0.008,
               start=0.6, anims=[fade_in(0.7)]))
    return t


# 7 — Üstte foto, altta daire numaralı üç adım; kademeli giriş.
def recipe_quick():
    t = Template("recipe-quick-01", tr="15 Dakikada", en="15-Minute Recipe",
                 category="food", pro=False, track="playful-01",
                 palette=PALETTES["forest"], duration=7.5)
    t.add(bg())
    t.add(media("photo", 0, y=0.21, h=0.42, radius=0.0,
                filter="vivid", intensity=0.4,
                anims=[fade_in(0.5), ken_burns(7.5, zoom=1.10, direction="down")]))
    t.add(scrim("scrim", direction="down", y=0.32, h=0.2))
    t.add(text("kicker", "kicker", "PRATİK TARİF", "QUICK RECIPE", 0.022,
               y=0.48, w=0.8, h=0.035, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.014, start=0.3,
               anims=[fade_in(0.55)]))
    t.add(text("title", "title", "15 Dakikada Hazır", "Ready in 15 Minutes", 0.052,
               y=0.555, w=0.86, h=0.075, font="AvenirNext-Heavy",
               role="textPrimary", start=0.45,
               anims=[slide_in("up", 0.04, 0.6)]))

    steps = [
        ("Suyu kaynat, makarnayı at", "Boil the water, drop the pasta"),
        ("Sarımsağı tereyağında çevir", "Sizzle the garlic in butter"),
        ("Karıştır, parmesanı rendele", "Toss together, grate the parmesan"),
    ]
    for i, (tr_step, en_step) in enumerate(steps):
        y = 0.68 + 0.10 * i
        t.add(shape(f"dot{i}", "accent", x=0.14, y=y, w=0.09, h=0.0506,
                    mask="circle", start=0.7 + 0.18 * i,
                    anims=[pop(1.12, 0.45)]))
        t.add(text(f"num{i}", f"step{i}Num", str(i + 1), str(i + 1), 0.026,
                   x=0.14, y=y, w=0.08, h=0.04, font="AvenirNext-Heavy",
                   role="textOnAccent", start=0.82 + 0.18 * i,
                   anims=[fade_in(0.3)]))
        t.add(text(f"step{i}", f"step{i}", tr_step, en_step, 0.028,
                   x=0.585, y=y, w=0.66, h=0.055, font="AvenirNext-Medium",
                   role="textPrimary", align="left", start=0.85 + 0.18 * i,
                   anims=[slide_in("right", 0.035, 0.5)]))
    return t


# 8 — Medyasız saf tipografi: koyu zemin, dört içecek satırı, ince ayraçlar.
def drinks_list():
    t = Template("drinks-list-01", tr="İçecek Listesi", en="Drinks List",
                 category="food", pro=True, track="ambient-01",
                 palette=PALETTES["charcoal"], duration=6.5)
    t.color("hairline", "#3A3A3E")
    t.add(bg())
    t.add(shape("glow", "accent", y=0.20, w=0.9, h=0.36, radius=0.2,
                opacity=0.10, anims=[scale_in(0.85, 0.9), pulse(3.0, 1.04)]))
    t.add(text("title", "title", "İçecekler", "Drinks", 0.064,
               y=0.185, w=0.84, h=0.09, font="Didot",
               role="textPrimary", start=0.25,
               anims=[slide_in("down", 0.03, 0.7)]))
    t.add(text("sub", "sub", "Sabah 8'den gece yarısına", "From 8 am to midnight",
               0.020, y=0.255, w=0.8, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", tracking=0.006, start=0.45,
               anims=[fade_in(0.6)]))
    t.add(shape("top-rule", "accent", y=0.315, w=0.72, h=0.003,
                start=0.6, anims=[wipe("right", 0.6)]))

    drinks = [
        ("Espresso Tonik", "Espresso Tonic", "₺95", "$6"),
        ("Sıcak Beyaz Çikolata", "White Hot Chocolate", "₺110", "$7"),
        ("Nane Limon Soda", "Mint Lemon Soda", "₺85", "$5"),
        ("Kestaneli Latte", "Chestnut Latte", "₺120", "$8"),
    ]
    for i, (tr_name, en_name, tr_price, en_price) in enumerate(drinks):
        y = 0.40 + 0.125 * i
        t.add(text(f"drink{i}-name", f"drink{i}Name", tr_name, en_name, 0.032,
                   x=0.31, y=y, w=0.38, h=0.06, font="AvenirNext-Medium",
                   role="textPrimary", align="left", start=0.75 + 0.14 * i,
                   anims=[slide_in("right", 0.03, 0.5)]))
        t.add(text(f"drink{i}-price", f"drink{i}Price", tr_price, en_price, 0.032,
                   x=0.79, y=y, w=0.20, h=0.06, font="AvenirNext-Heavy",
                   role="accent", align="right", start=0.85 + 0.14 * i,
                   anims=[fade_in(0.45)]))
        t.add(shape(f"drink{i}-rule", "hairline", y=y + 0.0625, w=0.72, h=0.002,
                    start=0.95 + 0.14 * i, anims=[wipe("right", 0.4)]))

    t.add(text("footer", "footer", "Fiyatlara servis dahildir",
               "Service included", 0.019, y=0.90, w=0.76, h=0.035,
               font="AvenirNext-Regular", role="textSecondary",
               start=1.2, anims=[fade_in(0.6)]))
    return t


# ------------------------------------------------------------------ promo

# 9 — Dev yüzde: çarpıcı accent zemin, ortada rakam, altta foto şeridi.
def flash_discount():
    t = Template("flash-discount-01", tr="Saatlik İndirim", en="Hourly Deal",
                 category="promo", pro=False, track="punchy-01",
                 palette=PALETTES["punch"], duration=5.5)
    t.add(bg("accent"))
    t.add(shape("halo", "background", y=0.34, w=0.94, h=0.44, radius=0.24,
                opacity=0.14, anims=[scale_in(0.86, 0.7), pulse(2.2, 1.04)]))
    t.add(text("kicker", "kicker", "İNDİRİM SAATİ", "HAPPY HOUR", 0.030,
               y=0.195, w=0.86, h=0.045, font="AvenirNext-DemiBold",
               role="textOnAccent", caps=True, tracking=0.018, start=0.25,
               anims=[slide_in("down", 0.04, 0.55)]))
    t.add(text("percent", "percent", "%50", "50%", 0.155,
               y=0.35, w=0.9, h=0.20, font="Archivo-SemiBold",
               role="textOnAccent", start=0.4,
               anims=[pop(1.14, 0.6), pulse(1.8, 1.03)]))
    t.add(shape("chip", "background", y=0.505, w=0.58, h=0.08, radius=0.04,
                start=0.75, anims=[scale_in(0.88, 0.5)]))
    t.add(text("chip-text", "chip", "SADECE BUGÜN", "TODAY ONLY", 0.032,
               y=0.505, w=0.55, h=0.05, font="AvenirNext-Heavy",
               role="textPrimary", caps=True, tracking=0.012, start=0.9,
               anims=[fade_in(0.4)]))
    t.add(media("strip", 0, y=0.795, w=0.86, h=0.27, radius=0.016,
                filter="vivid", intensity=0.5,
                anims=[wipe("right", 0.6, delay=0.6),
                       ken_burns(5.5, zoom=1.12, direction="left")]))
    t.add(text("terms", "terms", "Bugün 23:59'a kadar geçerli",
               "Valid until 11:59 pm today", 0.020,
               y=0.965, w=0.82, h=0.04, font="AvenirNext-Medium",
               role="textOnAccent", start=1.15, anims=[fade_in(0.6)]))
    return t


# 10 — İkiye bölünmüş kadraj: iki foto, ortada dairesel rozet.
def bogo_offer():
    t = Template("bogo-offer-01", tr="2 Al 1 Öde", en="Buy One Get One",
                 category="promo", pro=False, track="energetic-01",
                 palette=PALETTES["citrus"], duration=5.5)
    t.add(bg())
    t.add(media("left", 0, x=0.2475, y=0.5, w=0.495, h=1.0, kind="photo",
                filter="vivid", intensity=0.4,
                anims=[slide_in("right", 0.06, 0.6),
                       ken_burns(5.5, zoom=1.10, direction="up")]))
    t.add(media("right", 1, x=0.7525, y=0.5, w=0.495, h=1.0, kind="photo",
                filter="vivid", intensity=0.4,
                anims=[slide_in("left", 0.06, 0.6),
                       ken_burns(5.5, zoom=1.10, direction="down")]))
    t.add(scrim("scrim-top", direction="up", y=0.13, h=0.28))
    t.add(scrim("scrim-bottom", direction="down", y=0.86, h=0.28))
    t.add(text("kicker", "kicker", "SADECE BU HAFTA", "THIS WEEK ONLY", 0.030,
               y=0.135, w=0.86, h=0.05, font="AvenirNext-DemiBold",
               role="textPrimary", caps=True, tracking=0.016, start=0.3,
               anims=[fade_in(0.6)]))
    t.add(shape("badge-ring", "textPrimary", y=0.5, w=0.44, h=0.2475,
                mask="circle", opacity=0.9, start=0.5,
                anims=[scale_in(0.7, 0.55)]))
    t.add(shape("badge", "accent", y=0.5, w=0.40, h=0.225, mask="circle",
                start=0.6, anims=[pop(1.10, 0.5)]))
    t.add(text("badge-text", "badge", "2 AL\n1 ÖDE", "BUY 1\nGET 1", 0.048,
               y=0.5, w=0.34, h=0.13, font="AvenirNext-Heavy",
               role="textOnAccent", lines=2, caps=True, start=0.8,
               anims=[fade_in(0.4)]))
    t.add(text("terms", "terms", "İkinci ürün bizden — tüm tatlılarda",
               "Second one's on us — all desserts", 0.021,
               y=0.885, w=0.84, h=0.04, font="AvenirNext-Medium",
               role="textPrimary", start=1.0, anims=[slide_in("up", 0.03, 0.5)]))
    return t


# 11 — Bilet/kupon kartı: kesikli şerit, büyük harfli kod, geçerlilik satırı.
def coupon_code():
    t = Template("coupon-code-01", tr="Kupon Kodu", en="Coupon Code",
                 category="promo", pro=True, track="groovy-01",
                 palette=PALETTES["retro"], duration=6.0)
    t.color("cardInk", "#3A2A0C")
    t.add(bg())
    t.add(media("photo", 0, y=0.155, w=0.84, h=0.29, radius=0.016,
                filter="vintage", intensity=0.45,
                anims=[fade_in(0.5), ken_burns(6.0, zoom=1.09, direction="right")]))
    t.add(shape("card", "surface", y=0.60, w=0.84, h=0.50, radius=0.022,
                start=0.35, anims=[scale_in(0.93, 0.6)]))
    t.add(shape("notch-left", "background", x=0.08, y=0.60, w=0.07, h=0.0394,
                mask="circle", start=0.55, anims=[fade_in(0.35)]))
    t.add(shape("notch-right", "background", x=0.92, y=0.60, w=0.07, h=0.0394,
                mask="circle", start=0.55, anims=[fade_in(0.35)]))
    for i in range(11):
        t.add(shape(f"dash{i}", "cardInk", x=0.175 + 0.065 * i, y=0.60,
                    w=0.034, h=0.0035, opacity=0.45,
                    start=0.6 + 0.02 * i, anims=[fade_in(0.3)]))
    t.add(text("label", "label", "KUPON KODU", "COUPON CODE", 0.024,
               y=0.415, w=0.7, h=0.04, font="AvenirNext-DemiBold",
               role="cardInk", caps=True, tracking=0.02, start=0.6,
               anims=[fade_in(0.5)]))
    t.add(text("code", "code", "LEZZET25", "TASTE25", 0.072,
               y=0.50, w=0.78, h=0.11, font="Courier-Bold",
               role="cardInk", caps=True, tracking=0.02, start=0.75,
               anims=[pop(1.08, 0.55)]))
    t.add(text("value", "value", "Tüm siparişlerde %25 indirim",
               "25% off your whole order", 0.026,
               y=0.685, w=0.76, h=0.045, font="AvenirNext-Bold",
               role="cardInk", start=0.95, anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("valid", "valid", "31 Ağustos'a kadar geçerli",
               "Valid through August 31", 0.020,
               y=0.755, w=0.74, h=0.038, font="AvenirNext-Regular",
               role="cardInk", start=1.1, anims=[fade_in(0.55)]))
    t.add(text("where", "where", "Kasada göster ya da siteye yaz",
               "Show at the counter or use online", 0.019,
               y=0.93, w=0.82, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


# 12 — Temiz zemin, üstte ürün fotosu, altta kalın duyuru + alt limit.
def free_shipping():
    t = Template("free-shipping-01", tr="Kargo Bedava", en="Free Shipping",
                 category="promo", pro=False, track="clean-01",
                 palette=PALETTES["paper"], duration=6.0)
    t.add(bg("surface"))
    t.add(shape("tint", "background", y=0.30, w=1.0, h=0.60,
                opacity=0.55, anims=[fade_in(0.5)]))
    t.add(media("photo", 0, y=0.315, w=0.78, h=0.46, radius=0.012,
                filter="fade", intensity=0.3,
                anims=[scale_in(0.94, 0.6),
                       ken_burns(6.0, zoom=1.08, direction="up")]))
    t.add(shape("rule", "accent", y=0.635, w=0.11, h=0.004,
                start=0.55, anims=[wipe("right", 0.5)]))
    t.add(text("headline", "headline", "KARGO\nBEDAVA", "FREE\nSHIPPING", 0.076,
               y=0.755, w=0.86, h=0.19, font="AvenirNext-Heavy",
               role="textPrimary", lines=2, caps=True, tracking=0.004,
               start=0.65, anims=[slide_in("up", 0.045, 0.65)]))
    t.add(text("limit", "limit", "500 TL ve üzeri tüm siparişlerde",
               "On every order over $50", 0.023,
               y=0.885, w=0.84, h=0.04, font="AvenirNext-Medium",
               role="accent", start=0.95, anims=[fade_in(0.55)]))
    t.add(text("speed", "speed", "Bugün sipariş ver, yarın kapında",
               "Order today, here tomorrow", 0.019,
               y=0.945, w=0.82, h=0.035, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 13 — Montaj: nabız atan "SON GÜN" tipografisi, whip ile ürün kadrajına.
def last_chance():
    t = Template("last-chance-01", tr="Son Gün", en="Last Chance",
                 category="promo", pro=True, track="impact-01",
                 palette=PALETTES["electric"])

    hit = t.scene("hit", 2.4, transition="whip", transition_duration=0.35)
    hit.add(bg("background", "hit-bg"))
    hit.add(shape("hit-glow", "accent", y=0.45, w=0.86, h=0.42, radius=0.21,
                  opacity=0.16, anims=[scale_in(0.8, 0.7), pulse(1.6, 1.06)]))
    hit.add(text("hit-title", "hitTitle", "SON GÜN", "LAST DAY", 0.092,
                 y=0.45, w=0.9, h=0.15, font="AvenirNext-Heavy",
                 role="textPrimary", caps=True, tracking=0.012, start=0.2,
                 anims=[pop(1.16, 0.5), pulse(1.1, 1.05)]))
    hit.add(text("hit-sub", "hitSub", "İndirim gece yarısı bitiyor",
                 "The sale ends at midnight", 0.026,
                 y=0.575, w=0.84, h=0.05, font="AvenirNext-Medium",
                 role="accent", start=0.6, anims=[fade_in(0.5)]))

    show = t.scene("show", 3.6)
    # Sahne zemini YOK: montajda shape'ler medyanın ÜSTÜNE çizilir (2. geçiş);
    # compositor paletteki background'ı zaten boyar.
    show.add(media("show-media", 0, filter="cinematic", intensity=0.4,
                   anims=[ken_burns(3.6, zoom=1.13, direction="left")]))
    show.add(scrim("show-scrim", direction="down", y=0.76, h=0.48))
    show.add(shape("show-chip", "accent", x=0.24, y=0.155, w=0.32, h=0.072,
                   radius=0.036, start=0.25, anims=[slide_in("right", 0.06, 0.5)]))
    show.add(text("show-chip-text", "showChip", "SON 24 SAAT", "24 HOURS LEFT",
                  0.024, x=0.24, y=0.155, w=0.30, h=0.045,
                  font="AvenirNext-Heavy", role="textOnAccent", caps=True,
                  tracking=0.008, start=0.4, anims=[fade_in(0.35)]))
    show.add(text("show-title", "showTitle", "Tüm koleksiyonda %40",
                  "40% off everything", 0.058,
                  y=0.795, w=0.86, h=0.09, font="AvenirNext-Heavy",
                  role="textPrimary", start=0.5,
                  anims=[slide_in("up", 0.045, 0.6)]))
    show.add(text("show-cta", "showCta", "Profildeki bağlantıdan alışverişe",
                  "Shop from the link in bio", 0.022,
                  y=0.885, w=0.84, h=0.04, font="AvenirNext-Medium",
                  role="textSecondary", start=0.8, anims=[fade_in(0.6)]))
    return t


# 14 — Dikey ürün kartı, köşede dairesel rozet, altta ad/fiyat satırı.
def new_arrival():
    t = Template("new-arrival-01", tr="Yeni Geldi", en="New Arrival",
                 category="promo", pro=False, track="bright-01",
                 palette=PALETTES["mono"], duration=6.0)
    t.color("cardInk", "#111111")
    t.add(bg())
    t.add(text("kicker", "kicker", "YENİ SEZON", "NEW SEASON", 0.024,
               y=0.09, w=0.8, h=0.035, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.02, start=0.25,
               anims=[fade_in(0.55)]))
    t.add(shape("card", "surface", y=0.44, w=0.72, h=0.58, radius=0.018,
                start=0.35, anims=[scale_in(0.92, 0.6)]))
    t.add(media("photo", 0, y=0.42, w=0.62, h=0.48, radius=0.010,
                filter="mono", intensity=0.25,
                anims=[fade_in(0.6), ken_burns(6.0, zoom=1.09, direction="down")]))
    t.add(shape("badge", "accent", x=0.79, y=0.19, w=0.21, h=0.118,
                mask="circle", start=0.7, anims=[pop(1.14, 0.5)]))
    t.add(text("badge-text", "badge", "YENİ", "NEW", 0.030,
               x=0.79, y=0.19, w=0.18, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, tracking=0.006, start=0.85,
               anims=[fade_in(0.35)]))
    t.add(text("name", "name", "Keten Gömlek", "Linen Shirt", 0.040,
               x=0.33, y=0.80, w=0.38, h=0.07, font="AvenirNext-Bold",
               role="textPrimary", align="left", start=0.95,
               anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("price", "price", "₺1.290", "$149", 0.040,
               x=0.76, y=0.80, w=0.20, h=0.07, font="AvenirNext-Heavy",
               role="textPrimary", align="right", start=1.05,
               anims=[fade_in(0.45)]))
    t.add(text("stock", "stock", "Stoklarla sınırlı — 3 renk",
               "Limited stock — 3 colors", 0.020,
               y=0.90, w=0.8, h=0.038, font="AvenirNext-Regular",
               role="textSecondary", start=1.2, anims=[fade_in(0.6)]))
    return t


TEMPLATES = [
    cafe_menu, daily_special, coffee_shop, dessert_reveal, food_delivery,
    restaurant_tour, recipe_quick, drinks_list,
    flash_discount, bogo_offer, coupon_code, free_shipping, last_chance,
    new_arrival,
]
