"""REFERANS BATCH — kütüphanenin nasıl kullanıldığını gösteren örnekler.

Bu dosya `_` ile başladığı için `build-templates.py` tarafından ATLANIR;
üretime girmez, yalnız okunmak içindir. Yeni bir batch yazarken buradaki
altı örnek her düzen ailesini kapsar:

  1. full_bleed  — tam kadraj medya + alt köşede tipografi (en yaygın)
  2. editorial   — üstte medya, altta kart; dergi sayfası hissi
  3. type_only   — medyasız, saf tipografi (alıntı/duyuru)
  4. collage     — montaj, tek sahnede çoklu medya
  5. story_arc   — montaj, ardışık sahneler + geçiş
  6. card_stack  — maskeli medya + rozet + fiyat satırı

KURALLAR (hepsi lint'te zorunlu değil ama ürün kalitesi için geçerli):

- Her şablon `bg()` ile başlar. Kullanıcı medyasını seçmeden önce sahnede
  ne olduğu belli olmalı.
- Fotoğrafın üstüne metin geliyorsa MUTLAKA `scrim()` koy. Beyaz yazı açık
  bir fotoğrafta kayboluyor.
- Metin katmanı `timing` ile geç girsin (0.2–0.6 sn), hepsi aynı anda
  belirirse video ucuz görünüyor.
- Medya slotuna `ken_burns` ver: sabit fotoğraf videoyu ölü gösteriyor.
  Süresi katmanın PENCERESİNE eşit olmalı.
- Slot indeksleri 0'dan başlayıp ardışık ilerler (editör "1, 2, 3" diyor).
- `duration` 4–10 sn arası olsun; hikâye videosu izlenmiyor, göz atılıyor.
- Şablonun ADI kullanıcının işini anlatsın ("Kuaför Randevu", "Menü Kartı"),
  düzeni değil ("İkiz Ekran") — kullanıcı ne yapmak istediğini arıyor.

MONTAJ (v2) YOLUNUN EN ÖNEMLİ KURALI — bir kere 15 şablonda birden ihlal
edildi ve hepsi bomboş render oldu:

    Sahne içinde medya slotu VARSA, o sahneye OPAK bir zemin/kart koyma.

Motor montajı iki geçişte üretir: 1. geçiş medya slotlarını birleştirir,
2. geçiş shape ve text katmanlarını ONUN ÜSTÜNE çizer. Yani sahne içinde
yazdığın sıra medya ile shape arasında GEÇERLİ DEĞİLDİR — `bg()`'yi medyadan
önce yazsan bile üstte kalır ve kadrajı kapatır. Sahne zemini zaten
gereksiz: compositor paletteki `background` rengini kendisi boyar.

  ✗  s.add(bg())                       # tüm videoyu kapatır
  ✗  s.add(shape("kart", ...))         # fotoğraftan büyük arkalık → örter
  ✓  s.add(scrim())                    # yarı saydam, okunurluk için gerekli
  ✓  s.add(shape("rozet", ...))        # medyadan küçük, bilerek ÜSTTE

Fotoğrafın ARKASINA bir şey koyman gerekiyorsa (polaroid çerçevesi gibi)
şablon KLASİK (v1) olmalı — v1 katman sırasını korur ve foto slotu sayısını
sınırlamaz (sınır yalnız video slotunda: en fazla 1).

Lint bu kuralın ikisini de yakalar; hata alırsan düzeni değiştir, bastırma.
"""

from templatelib import *   # noqa: F403


# 1 — Tam kadraj: tek medya, alt köşede başlık. Katalogdaki en yaygın iskelet.
def full_bleed():
    t = Template("ref-full-bleed", tr="Tam Kadraj", en="Full Bleed",
                 category="social", track="upbeat-01",
                 palette=PALETTES["charcoal"], duration=6.0)
    t.add(bg())
    t.add(media("photo", 0, filter="vivid", intensity=0.6,
                anims=[fade_in(0.6), ken_burns(6.0, zoom=1.12, direction="up")]))
    t.add(scrim())
    t.add(text("kicker", "kicker", "BUGÜN", "TODAY", 0.022,
               y=0.72, w=0.8, h=0.04, font="AvenirNext-DemiBold",
               role="accent", caps=True, tracking=0.006,
               start=0.5, anims=[slide_in("up", 0.04, 0.5)]))
    t.add(text("headline", "headline", "BAŞLIĞINIZ\nBURADA", "YOUR TITLE\nHERE", 0.062,
               y=0.81, w=0.86, h=0.16, font="AvenirNext-Heavy",
               lines=2, caps=True, start=0.65,
               anims=[slide_in("up", 0.05, 0.6)]))
    t.add(text("handle", "handle", "@kullanici", "@yourhandle", 0.02,
               y=0.92, w=0.7, h=0.035, role="textSecondary",
               tracking=0.004, start=1.0, anims=[fade_in(0.5)]))
    return t


# 2 — Editorial: üstte medya, altta zemin kartı. Metin fotoğrafla yarışmaz.
def editorial():
    t = Template("ref-editorial", tr="Dergi Sayfası", en="Editorial",
                 category="minimal", track="calm-01",
                 palette=PALETTES["ivory"], duration=6.5)
    t.add(bg("surface"))
    t.add(media("photo", 0, y=0.33, h=0.62, filter="fade", intensity=0.35,
                anims=[fade_in(0.7), ken_burns(6.5, zoom=1.08, direction="down")]))
    t.add(shape("rule", "accent", y=0.685, w=0.1, h=0.004,
                start=0.6, anims=[wipe("right", 0.6)]))
    t.add(text("kicker", "kicker", "SEÇKİ", "SELECTED", 0.019,
               y=0.72, w=0.7, h=0.035, font="AvenirNext-Medium",
               role="textSecondary", caps=True, tracking=0.008,
               start=0.7, anims=[fade_in(0.5)]))
    t.add(text("title", "title", "Sade bir\nbaşlık", "A quiet\nheadline", 0.058,
               y=0.815, w=0.82, h=0.16, font="Didot", role="textPrimary",
               lines=2, start=0.85, anims=[slide_in("up", 0.03, 0.7)]))
    t.add(text("sub", "sub", "Kısa bir alt yazı", "A short subtitle", 0.021,
               y=0.905, w=0.78, h=0.04, font="AvenirNext-Regular",
               role="textSecondary", start=1.15, anims=[fade_in(0.6)]))
    return t


# 3 — Yalnız tipografi: medya slotu YOK. Editörde "Medya" sekmesi boş kalır,
#     kullanıcı sadece yazıp paylaşır — en hızlı iş.
def type_only():
    t = Template("ref-type-only", tr="Söz Kartı", en="Word Card",
                 category="minimal", track="ambient-01",
                 palette=PALETTES["grape"], duration=5.0)
    t.add(bg())
    t.add(shape("glow", "accent", y=0.42, w=0.9, h=0.5, radius=0.25,
                opacity=0.18, anims=[scale_in(0.8, 1.0), pulse(2.4, 1.05)]))
    t.add(text("quote", "quote", "Sözünüz\nburada.", "Your words\nhere.", 0.072,
               y=0.44, w=0.82, h=0.28, font="Georgia-Bold",
               lines=3, start=0.35, anims=[slide_in("up", 0.04, 0.7)]))
    t.add(shape("dash", "accent", y=0.63, w=0.08, h=0.005,
                start=0.9, anims=[wipe("right", 0.5)]))
    t.add(text("author", "author", "— ADINIZ", "— YOUR NAME", 0.022,
               y=0.69, w=0.7, h=0.04, font="AvenirNext-DemiBold",
               role="textSecondary", caps=True, tracking=0.01,
               start=1.05, anims=[fade_in(0.6)]))
    return t


# 4 — Kolaj: tek sahne, dört medya. Montaj (v2) yolu; sahne başına ≤4 video.
def collage():
    t = Template("ref-collage", tr="Dörtlü Kolaj", en="Quad Collage",
                 category="travel", track="wanderlust-01",
                 palette=PALETTES["ocean"], pro=True)
    s = t.scene("grid", 5.0)
    cells = [(0.2525, 0.29), (0.7475, 0.29), (0.2525, 0.71), (0.7475, 0.71)]
    for i, (x, y) in enumerate(cells):
        s.add(media(f"cell{i}", i, x=x, y=y, w=0.49, h=0.415, kind="video",
                    radius=0.01, filter="cool", intensity=0.4,
                    anims=[scale_in(0.88, 0.5, delay=0.07 * i),
                           ken_burns(5.0, zoom=1.06, direction="up")]))
    s.add(shape("chip", "surface", y=0.5, w=0.44, h=0.075, radius=0.038,
                start=0.5, anims=[pop(1.08, 0.5)]))
    s.add(text("place", "place", "İSTANBUL", "ISTANBUL", 0.03,
               y=0.5, w=0.42, h=0.05, font="AvenirNext-Heavy",
               role="background", caps=True, tracking=0.008,
               start=0.6, anims=[fade_in(0.4)]))
    return t


# 5 — Hikâye yayı: ardışık sahneler + geçiş. Giriş → içerik → kapanış.
def story_arc():
    t = Template("ref-story-arc", tr="Hikâye Akışı", en="Story Arc",
                 category="social", track="beat-01",
                 palette=PALETTES["punch"], pro=True)

    # DİKKAT: medya taşıyan sahneye zemin shape'i KONMAZ (yukarıdaki kural).
    intro = t.scene("intro", 2.2, transition="whip", transition_duration=0.35)
    intro.add(media("intro-media", 0, kind="video", filter="vivid", intensity=0.5,
                    anims=[ken_burns(2.2, zoom=1.15, direction="down")]))
    intro.add(scrim("intro-scrim", direction="up"))
    intro.add(text("hook", "hook", "HAZIR MISIN?", "READY?", 0.075,
                   y=0.44, w=0.86, h=0.14, font="AvenirNext-Heavy",
                   caps=True, start=0.2, anims=[pop(1.1, 0.5)]))

    mid = t.scene("mid", 3.0, transition="crossDissolve", transition_duration=0.4)
    mid.add(media("mid-media", 1, kind="video",
                  anims=[ken_burns(3.0, zoom=1.1, direction="left")]))
    mid.add(scrim("mid-scrim"))
    mid.add(text("body", "body", "Ne anlatmak\nistiyorsan", "Whatever you\nwant to say", 0.05,
                 y=0.8, w=0.84, h=0.14, font="AvenirNext-Bold", lines=2,
                 start=0.3, anims=[slide_in("up", 0.05, 0.5)]))

    outro = t.scene("outro", 2.4)
    outro.add(bg("background", "outro-bg"))
    outro.add(shape("outro-mark", "accent", y=0.44, w=0.22, h=0.124, mask="circle",
                    anims=[scale_in(0.6, 0.6)]))
    outro.add(text("cta", "cta", "TAKİP ET", "FOLLOW", 0.048,
                   y=0.62, w=0.8, h=0.09, font="AvenirNext-Heavy",
                   caps=True, tracking=0.01, start=0.35,
                   anims=[slide_in("up", 0.04, 0.5)]))
    return t


# 6 — Kart yığını: maskeli medya + rozet + sola/sağa yaslı satır.
def card_stack():
    t = Template("ref-card-stack", tr="Ürün Kartı", en="Product Card",
                 category="promo", track="clean-01",
                 palette=PALETTES["sand"], duration=6.0)
    t.add(bg("surface"))
    t.add(shape("panel", "background", y=0.44, w=0.86, h=0.56, radius=0.02,
                anims=[scale_in(0.94, 0.6)]))
    t.add(media("photo", 0, y=0.42, w=0.78, h=0.46, radius=0.014,
                filter="warm", intensity=0.5,
                anims=[fade_in(0.6), ken_burns(6.0, zoom=1.09, direction="up")]))
    t.add(shape("badge", "accent", x=0.76, y=0.19, w=0.26, h=0.075,
                radius=0.038, rotation=-8, start=0.55,
                anims=[bounce(0.65)]))
    t.add(text("badge-text", "badge", "YENİ", "NEW", 0.03,
               x=0.76, y=0.19, w=0.24, h=0.05, font="AvenirNext-Heavy",
               role="textOnAccent", caps=True, rotation=-8, start=0.65,
               anims=[fade_in(0.35)]))
    t.add(text("name", "name", "Ürün adı", "Product name", 0.042,
               x=0.34, y=0.775, w=0.44, h=0.07, font="AvenirNext-Bold",
               role="textPrimary", align="left", start=0.8,
               anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("price", "price", "₺249", "$29", 0.042,
               x=0.78, y=0.775, w=0.28, h=0.07, font="AvenirNext-Heavy",
               role="accent", align="right", start=0.9,
               anims=[slide_in("up", 0.03, 0.5)]))
    t.add(text("cta", "cta", "Profildeki bağlantıdan", "Link in bio", 0.021,
               y=0.87, w=0.7, h=0.04, font="AvenirNext-Medium",
               role="textSecondary", start=1.1, anims=[fade_in(0.6)]))
    return t


TEMPLATES = [full_bleed, editorial, type_only, collage, story_arc, card_stack]
