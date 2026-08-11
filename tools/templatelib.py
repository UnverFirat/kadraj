#!/usr/bin/env python3
"""Şablon üretim kütüphanesi.

NEDEN VAR: katalog 29'dan 100 şablona çıkarken her şablonu elle JSON yazmak
hem yavaş hem de hataya açıktı — motorun sözleşmesi (normalize koordinat,
palet rolleri, benzersiz katman/slot kimlikleri, sahne süreleri) her dosyada
tekrar tekrar doğru kurulmak zorunda. Burası o sözleşmeyi TEK yerde tutar:
şablon yazan kişi düzeni tarif eder, kütüphane geçerli JSON'u üretir.

Kullanım (bir batch dosyasından):

    from templatelib import *

    def cafe_menu():
        t = Template("cafe-menu-01", tr="Kafe Menüsü", en="Cafe Menu",
                     category="food", pro=False, track="warm-01",
                     palette=PALETTES["cream"], duration=7.0)
        t.add(bg())
        t.add(media("photo", 0, h=0.46, y=0.23, filter="warm"))
        ...
        return t

`build-templates.py` batch dosyalarını çalıştırıp `templates/` altına yazar ve
her dosyayı `lint()`'ten geçirir. Lint, motorun `TemplateValidator`'ındaki
kuralların Python karşılığıdır ARTI gözle görülemeyen tasarım hatalarını
(kadraj dışına taşan katman, okunamayacak kadar küçük yazı, üst üste binen
metin blokları) yakalar — 100 şablonu tek tek göz kontrolünden geçirmek
mümkün değil, bu yüzden yapısal kontrol otomatik olmak zorunda.
"""

from __future__ import annotations

import copy
import json

CANVAS = {"width": 1080, "height": 1920, "fps": 30}
SCHEMA_V1 = 1
SCHEMA_V2 = 2

# MusicLibrary.all içindeki parça kimlikleri. Şablonun `defaultTrackId`'si
# burada YOKSA `testEveryTemplateDefaultTrackExists` kırmızıya döner.
TRACKS = {
    "calm-01", "ambient-01", "smooth-01", "typewriter-01",
    "warm-01", "acoustic-01", "sweet-01", "chill-01",
    "cinematic-01", "dreamy-01", "impact-01", "anticipation-01",
    "upbeat-01", "energetic-01", "beat-01", "punchy-01",
    "groovy-01", "playful-01", "bright-01", "wanderlust-01", "clean-01",
}

# TemplateCategory.order ile AYNI olmak zorunda (test: her kategori orada
# tanımlı olmalı, yoksa galeri sırası bilinmez).
CATEGORIES = [
    "travel", "social", "business", "promo", "food", "wedding", "minimal",
    "fashion", "fitness", "beauty", "education", "music", "holiday", "realestate",
]

# Uygulamayla gelen fontlar (PostScript adları). Motor bulamazsa sistem
# fontuna düşer ama tipografi bozulur — listede olmayan font kullanma.
FONTS = {
    "AvenirNext-Heavy", "AvenirNext-Bold", "AvenirNext-DemiBold",
    "AvenirNext-Medium", "AvenirNext-Regular",
    "Archivo-SemiBold", "Archivo-Regular",
    "Georgia-Bold", "Georgia-Italic", "Didot",
    "SnellRoundhand-Bold", "Courier-Bold",
}

FILTERS = {"warm", "cool", "vintage", "mono", "vivid", "cinematic", "fade"}
# AnimationFactory'nin tanıdığı preset'ler. Buradaki liste motordakiyle aynı
# olmalı — motor tanımadığı preset'i sessizce ATLAR, yani yazım hatası şablonu
# kırmaz ama animasyonu görünmez yapar. Lint bunu yakalasın.
PRESETS = {"fadeIn", "fadeOut", "slideIn", "slideOut", "scaleIn", "pop",
           "kenBurns", "wipeReveal", "bounce", "pulse", "typewriter",
           "punchIn", "spinIn", "swingIn", "floatLoop", "shake", "kineticWords"}
MASKS = {"rect", "circle", "star", "heart"}
TRANSITIONS = {"cut", "crossDissolve", "blurDissolve", "slide", "slideLeft",
               "slideRight", "slideUp", "slideDown", "zoomIn", "zoomOut", "whip"}


# ---------------------------------------------------------------- paletler
#
# Her palet `background/surface/accent/textPrimary/textSecondary` taşır ve
# scrim rolleriyle (`scrimClear`/`scrimSolid`) gelir: metnin fotoğraf üstünde
# okunması için gradient scrim şart — düz renkli bant kadrajı sert kesiyor.

def _palette(background, surface, accent, text_primary, text_secondary,
             text_on_accent="#FFFFFF", **extra):
    base = {
        "background": background,
        "surface": surface,
        "accent": accent,
        "textPrimary": text_primary,
        "textSecondary": text_secondary,
        "textOnAccent": text_on_accent,
        "scrimClear": "#00000000",
        "scrimSolid": "#000000CC",
    }
    base.update(extra)
    return base


PALETTES = {
    # Sıcak / doğal
    "cream":     _palette("#F5EFE6", "#FFFFFF", "#C0763A", "#2B231C", "#7A6A5B", text_on_accent="#FFF8F0"),
    "sand":      _palette("#E8DCC8", "#FFFDF8", "#8C6A43", "#31281E", "#7C6C58"),
    "terracotta":_palette("#2A1B16", "#F3E4D7", "#E2703A", "#FFF6EF", "#D6B7A4"),
    "honey":     _palette("#1A1408", "#FFFFFF", "#F2B705", "#FFFCF0", "#CBBE9A", text_on_accent="#1A1408"),
    # Soğuk / gece
    "midnight":  _palette("#0B0B12", "#FFFFFF", "#6C8CFF", "#F4F5FF", "#A8ADC4"),
    "ocean":     _palette("#06202B", "#EAF7FB", "#2BB3C0", "#F2FBFD", "#9CC3CE"),
    "forest":    _palette("#0D1A12", "#F0F7F1", "#3FA06A", "#F3FAF4", "#A6C2AE"),
    "slate":     _palette("#15171C", "#FFFFFF", "#8FA3B8", "#F7F9FC", "#A9B3C0"),
    # Canlı / promo
    "punch":     _palette("#101014", "#FFFFFF", "#FF2E63", "#FFFFFF", "#C9C9D1"),
    "electric":  _palette("#08080C", "#FFFFFF", "#00E5A0", "#FFFFFF", "#9FB3AC", text_on_accent="#06120D"),
    "sunset":    _palette("#1B0F1E", "#FFF3E9", "#FF7A45", "#FFF3E9", "#D3AFA0"),
    "grape":     _palette("#160B2B", "#FFFFFF", "#B06BFF", "#F6F0FF", "#B9A9D4"),
    "citrus":    _palette("#12140A", "#FFFFFF", "#D8F135", "#FBFFE6", "#BDC79A", text_on_accent="#12140A"),
    # Zarif / minimal
    "ivory":     _palette("#FBFAF7", "#FFFFFF", "#B99566", "#1A1815", "#8A857D", text_on_accent="#FFFFFF"),
    "charcoal":  _palette("#111113", "#FFFFFF", "#D9A441", "#FFFFFF", "#B0B0B4"),
    "blush":     _palette("#F7EDEC", "#FFFFFF", "#C98B8B", "#2B1F1F", "#8E7676"),
    "mono":      _palette("#0A0A0A", "#FFFFFF", "#FFFFFF", "#FFFFFF", "#9A9A9A", text_on_accent="#0A0A0A"),
    "paper":     _palette("#EFEAE2", "#FFFFFF", "#1F1D1A", "#1F1D1A", "#6F6A62"),
    # Karakterli
    "retro":     _palette("#1E1305", "#F7E7C4", "#E4A11B", "#FDF3DD", "#C9A96B", text_on_accent="#1E1305"),
    "neon":      _palette("#06060F", "#FFFFFF", "#19E1FF", "#FFFFFF", "#8FA9B4", text_on_accent="#06060F"),
    "rose":      _palette("#1C0F14", "#FFF0F4", "#F0698E", "#FFF0F4", "#D6A9B7"),
    "steel":     _palette("#0F1216", "#E8EEF5", "#4C9BE8", "#F3F7FC", "#9AA9BB"),
}


# ------------------------------------------------------------- animasyonlar

def fade_in(d=0.6, delay=0.0, easing=None):
    return _anim("in", "fadeIn", d, delay, easing)


def fade_out(d=0.5, delay=0.0):
    return _anim("out", "fadeOut", d, delay, None)


def slide_in(direction="up", distance=0.06, d=0.6, delay=0.0, easing="easeOut"):
    return _anim("in", "slideIn", d, delay, easing,
                 {"direction": direction, "distance": distance})


def slide_out(direction="down", distance=0.06, d=0.45, delay=0.0):
    return _anim("out", "slideOut", d, delay, None,
                 {"direction": direction, "distance": distance})


def scale_in(start=0.85, d=0.55, delay=0.0, easing="easeOut"):
    return _anim("in", "scaleIn", d, delay, easing, {"from": start})


def pop(overshoot=1.08, d=0.5, delay=0.0):
    return _anim("in", "pop", d, delay, None, {"overshoot": overshoot})


def bounce(d=0.7, delay=0.0):
    return _anim("in", "bounce", d, delay, None)


def wipe(direction="right", d=0.7, delay=0.0, easing="easeOut"):
    return _anim("in", "wipeReveal", d, delay, easing, {"direction": direction})


def typewriter(d=1.4, delay=0.0):
    return _anim("in", "typewriter", d, delay, None)


def ken_burns(d, zoom=1.12, direction="up"):
    """Ken Burns süresi PENCEREYE eşit olmalı — kısa verilirse hareket erken
    biter ve kare donar."""
    return _anim("loop", "kenBurns", d, 0.0, None,
                 {"zoom": zoom, "direction": direction})


def punch_in(d=0.5, delay=0.0, start=1.6):
    """Sert yaklaşma. Ritme vuran giriş — fadeIn'in slayt hissini kıran hamle."""
    return _anim("in", "punchIn", d, delay, None, {"from": start})


def spin_in(d=0.6, delay=0.0, degrees=12, start=0.82):
    return _anim("in", "spinIn", d, delay, "easeOut",
                 {"degrees": degrees, "from": start})


def swing_in(d=0.8, delay=0.0, degrees=14):
    """Sallanarak asılma — rozet/sticker girişi."""
    return _anim("in", "swingIn", d, delay, None, {"degrees": degrees})


def kinetic_words(d=1.2, delay=0.0, distance=0.02):
    """Kelime kelime giriş. Çok kelimeli BAŞLIKLARDA kullan; tek kelimede
    etkisi yok (motor düz metne düşer)."""
    return _anim("in", "kineticWords", d, delay, None, {"distance": distance})


def float_loop(d=2.0, distance=0.008, axis="y"):
    """Sürekli hafif süzülme. Tek sahneli şablonlara can veren en ucuz katman —
    `role: loop` olduğu için katmanın penceresi boyunca tekrarlar."""
    return _anim("loop", "floatLoop", d, 0.0, None,
                 {"distance": distance, "axis": axis})


def shake(d=1.2, delay=0.0, degrees=2.5):
    """Dikkat çeken küçük titreşim (rozet, CTA)."""
    return _anim("loop", "shake", d, delay, None, {"degrees": degrees})


def pulse(d=1.2, scale=1.06, axis=None):
    params = {"scale": scale}
    if axis:
        params["axis"] = axis
    return _anim("loop", "pulse", d, 0.0, None, params)


def _anim(role, preset, duration, delay, easing, params=None):
    a = {"role": role, "preset": preset, "duration": round(duration, 3)}
    if delay:
        a["delay"] = round(delay, 3)
    if easing:
        a["easing"] = easing
    if params:
        a["params"] = params
    return a


# ----------------------------------------------------------------- katmanlar

def _frame(x, y, w, h):
    return {"x": round(x, 4), "y": round(y, 4),
            "width": round(w, 4), "height": round(h, 4)}


def _timing(start=None, duration=None):
    t = {}
    if start is not None:
        t["start"] = round(start, 3)
    if duration is not None:
        t["duration"] = round(duration, 3)
    return t or None


def _base(layer_id, x, y, w, h, rotation=0, opacity=1.0,
          start=None, dur=None, anims=None):
    layer = {"id": layer_id, "frame": _frame(x, y, w, h)}
    if rotation:
        layer["rotation"] = rotation
    if opacity != 1.0:
        layer["opacity"] = opacity
    timing = _timing(start, dur)
    if timing:
        layer["timing"] = timing
    if anims:
        layer["animations"] = list(anims)
    return layer


def bg(role="background", layer_id="bg"):
    """Tam kadraj düz zemin. Her şablon bununla başlamalı: medya slotu boşken
    (kullanıcı henüz seçmediyse) altta ne olduğu belirsiz kalmasın."""
    layer = _base(layer_id, 0.5, 0.5, 1.0, 1.0)
    layer.update({"type": "shape", "colorRole": role})
    return layer


def shape(layer_id, role, x=0.5, y=0.5, w=1.0, h=1.0, radius=0.0, mask=None,
          rotation=0, opacity=1.0, gradient=None, start=None, dur=None, anims=None):
    layer = _base(layer_id, x, y, w, h, rotation, opacity, start, dur, anims)
    layer["type"] = "shape"
    layer["colorRole"] = role
    if radius:
        layer["cornerRadius"] = round(radius, 4)
    if mask:
        layer["mask"] = mask
    if gradient:
        layer["gradient"] = gradient
    return layer


def scrim(layer_id="scrim", direction="down", frm="scrimClear", to="scrimSolid",
          x=0.5, y=0.5, w=1.0, h=1.0, start=None, dur=None, anims=None):
    """Metin okunurluğu için gradient karartma. Düz renkli bant yerine HER
    ZAMAN bunu kullan — düz bant kadrajı sert bir çizgiyle ikiye bölüyor."""
    return shape(layer_id, frm, x, y, w, h, start=start, dur=dur, anims=anims,
                 gradient={"from": frm, "to": to, "direction": direction})


def media(layer_id, slot, x=0.5, y=0.5, w=1.0, h=1.0, kind="photoOrVideo",
          mask="rect", radius=0.0, filter=None, intensity=None,
          rotation=0, start=None, dur=None, anims=None):
    layer = _base(layer_id, x, y, w, h, rotation, 1.0, start, dur, anims)
    layer["type"] = "mediaSlot"
    layer["slotIndex"] = slot
    layer["media"] = kind
    layer["contentMode"] = "fill"
    layer["mask"] = mask
    if radius:
        layer["cornerRadius"] = round(radius, 4)
    if filter:
        layer["filter"] = filter
        if intensity is not None:
            layer["filterIntensity"] = intensity
    return layer


def text(layer_id, key, tr, en, size, x=0.5, y=0.5, w=0.84, h=0.1,
         font="AvenirNext-Bold", role="textPrimary", align="center",
         lines=1, tracking=0.0, caps=False, highlight=None,
         rotation=0, opacity=1.0, start=None, dur=None, anims=None):
    layer = _base(layer_id, x, y, w, h, rotation, opacity, start, dur, anims)
    layer["type"] = "text"
    layer["key"] = key
    layer["default"] = {"en": en, "tr": tr}
    layer["font"] = {"name": font, "size": round(size, 4)}
    layer["colorRole"] = role
    if highlight:
        layer["highlightColorRole"] = highlight
    layer["alignment"] = align
    if lines != 1:
        layer["maxLines"] = lines
    if tracking:
        layer["letterSpacing"] = round(tracking, 4)
    if caps:
        layer["allCaps"] = True
    return layer


def sticker(layer_id, key, emoji, size=0.09, x=0.5, y=0.5, rotation=0,
            start=None, dur=None, anims=None):
    """Emoji çıkartma. Ayrı katman tipi yok — CoreText emoji'yi renkli çizer,
    `pop`/`rotation` ile sticker etkisi verir."""
    return text(layer_id, key, emoji, emoji, size, x=x, y=y,
                w=size * 2.2, h=size * 1.6, rotation=rotation,
                start=start, dur=dur, anims=anims or [pop()])


def lottie(layer_id, asset, x=0.5, y=0.5, w=1.0, h=1.0, loop="loop",
           remap=None, start=None, dur=None):
    layer = _base(layer_id, x, y, w, h, start=start, dur=dur)
    layer["type"] = "lottie"
    layer["asset"] = asset
    layer["loopMode"] = loop
    if remap:
        layer["colorRemap"] = remap
    return layer


# ------------------------------------------------------------------- sahne

class Scene:
    def __init__(self, scene_id, duration, transition=None, transition_duration=0.5):
        self.id = scene_id
        self.duration = duration
        self.layers = []
        self.transition = transition
        self.transition_duration = transition_duration

    def add(self, *layers):
        for layer in layers:
            self.layers.append(layer)
        return self

    def build(self):
        scene = {"id": self.id, "duration": round(self.duration, 3),
                 "layers": self.layers}
        if self.transition:
            scene["transition"] = {"style": self.transition,
                                   "duration": round(self.transition_duration, 3)}
        return scene


# ---------------------------------------------------------------- şablon

class Template:
    """Bir şablon dosyası.

    `duration` verilirse klasik (v1) şablon; `scene()` çağrılırsa montaj (v2)
    olur. İkisi karışmaz — montajda üst düzey `layers` yalnız TÜM montaj
    boyunca görünen global overlay'lerdir (kalıcı logo, filigran çizgisi).
    """

    def __init__(self, template_id, tr, en, category, track, palette,
                 pro=False, duration=None, volume=0.85, overlay=None, calm=False):
        self.id = template_id
        self.name = {"en": en, "tr": tr}
        self.category = category
        self.pro = pro
        self.track = track
        self.volume = volume
        self.palette = dict(palette)
        self.duration = duration
        self.overlay = overlay
        self.layers = []
        self.scenes = []
        # True ise `enliven()` bu şablona dokunmaz (bilerek sakin tasarımlar:
        # davetiye, bayram tebriği, alıntı kartı gibi).
        self.calm = calm

    def color(self, role, hex_value):
        """Palete ek rol. Şablona özgü bir vurgu rengi gerektiğinde."""
        self.palette[role] = hex_value
        return self

    def add(self, *layers):
        for layer in layers:
            self.layers.append(layer)
        return self

    def scene(self, scene_id, duration, transition=None, transition_duration=0.5):
        s = Scene(scene_id, duration, transition, transition_duration)
        self.scenes.append(s)
        return s

    @property
    def total_duration(self):
        if self.scenes:
            total = sum(s.duration for s in self.scenes)
            total -= sum(s.transition_duration for s in self.scenes[:-1] if s.transition)
            return total
        return self.duration or 0

    def build(self):
        doc = {
            "schemaVersion": SCHEMA_V2 if self.scenes else SCHEMA_V1,
            "id": self.id,
            "name": self.name,
            "category": self.category,
            "isPro": self.pro,
            "canvas": dict(CANVAS),
        }
        if not self.scenes:
            doc["duration"] = round(self.duration, 3)
        doc["palette"] = self.palette
        if self.overlay:
            doc["overlay"] = self.overlay
        doc["audio"] = {"defaultTrackId": self.track, "volume": self.volume}
        if self.scenes:
            doc["scenes"] = [s.build() for s in self.scenes]
        doc["layers"] = self.layers
        if self.calm:
            doc["_calm"] = True
        return doc


# -------------------------------------------------------------------- lint

class LintError(Exception):
    pass


def lint(doc, strict=True):
    """Şablonu motorun kabul edeceğinden ve GÖRÜNTÜNÜN bozuk olmayacağından
    emin olur. Hata listesi döner (boşsa temiz)."""
    errors = []
    e = errors.append

    tid = doc.get("id", "<id yok>")
    if not doc.get("name", {}).get("en") or not doc.get("name", {}).get("tr"):
        e(f"{tid}: name hem 'tr' hem 'en' taşımalı")
    if doc.get("category") not in CATEGORIES:
        e(f"{tid}: bilinmeyen kategori '{doc.get('category')}' "
          f"(TemplateCategory.order'a eklenmeli)")
    track = doc.get("audio", {}).get("defaultTrackId")
    if track not in TRACKS:
        e(f"{tid}: tanınmayan müzik parçası '{track}'")

    palette = doc.get("palette", {})
    for role, value in palette.items():
        if not (isinstance(value, str) and value.startswith("#")
                and len(value) in (7, 9)):
            e(f"{tid}: palet rolü '{role}' geçersiz renk '{value}'")

    scenes = doc.get("scenes")
    layer_ids = set()
    slot_indexes = set()

    def opaque_shape(layer):
        """Arkasındakini gizleyecek kadar opak bir shape mi?"""
        if layer.get("type") != "shape":
            return False
        if layer.get("opacity", 1.0) < 0.85:
            return False
        gradient = layer.get("gradient")
        if gradient:
            ends = [palette.get(gradient.get("from"), "#000000"),
                    palette.get(gradient.get("to"), "#000000")]
            return all(len(c) == 7 or c[7:9].upper() == "FF" for c in ends)
        role_color = palette.get(layer.get("colorRole"), "#000000")
        return len(role_color) == 7 or role_color[7:9].upper() == "FF"

    def opaque_full_frame(layer):
        """Medyayı tamamen örtecek bir shape mi?

        MONTAJ (v2) YOLUNUN KURALI: medya slotları 1. geçişte (MontageComposer)
        birleştirilir, shape/text katmanları 2. geçişte (CoreAnimationTool)
        ÜSTÜNE çizilir. Yani sahne içindeki katman sırası medya ile shape
        arasında GEÇERLİ DEĞİLDİR — hangi sırada yazarsan yaz, opak bir shape
        medyanın üstünde kalır ve kadrajı bembeyaz/bomboş gösterir.
        (Bu tuzağa 8 şablonda birden düşüldü: polaroid kartı fotoğrafın,
        sahne zemini de tüm görüntünün üstünü kapattı.)

        Sahne zemini zaten gereksiz: compositor paletteki `background` rengini
        kendisi boyar.
        """
        if layer.get("type") != "shape":
            return False
        frame = layer.get("frame", {})
        area = frame.get("width", 0) * frame.get("height", 0)
        if area < 0.8:
            return False
        if layer.get("opacity", 1.0) < 0.85:
            return False
        gradient = layer.get("gradient")
        if gradient:
            # Şeffaflığa giden gradient (scrim) sorun değil; iki ucu da opaksa
            # düz renk gibi örter.
            ends = [palette.get(gradient.get("from"), "#000000"),
                    palette.get(gradient.get("to"), "#000000")]
            return all(len(c) == 7 or c[7:9].upper() == "FF" for c in ends)
        role_color = palette.get(layer.get("colorRole"), "#000000")
        return len(role_color) == 7 or role_color[7:9].upper() == "FF"

    def check_layers(layers, container_duration, where, video_budget):
        video_capable = 0
        text_boxes = []
        for layer in layers:
            lid = layer.get("id")
            if lid in layer_ids:
                e(f"{tid}: katman id'si tekrar ediyor '{lid}' "
                  f"(sahneler dahil TÜM şablonda benzersiz olmalı)")
            layer_ids.add(lid)

            frame = layer.get("frame", {})
            for key in ("x", "y", "width", "height"):
                if key not in frame:
                    e(f"{tid}/{lid}: frame.{key} eksik")
            if frame:
                left = frame["x"] - frame["width"] / 2
                right = frame["x"] + frame["width"] / 2
                top = frame["y"] - frame["height"] / 2
                bottom = frame["y"] + frame["height"] / 2
                if strict and (left < -0.03 or right > 1.03
                               or top < -0.03 or bottom > 1.03):
                    e(f"{tid}/{lid}: katman kadrajın dışına taşıyor "
                      f"(x {left:.2f}–{right:.2f}, y {top:.2f}–{bottom:.2f})")

            timing = layer.get("timing", {})
            start = timing.get("start", 0)
            dur = timing.get("duration", container_duration - start)
            if start < 0:
                e(f"{tid}/{lid}: timing.start negatif")
            if start + dur > container_duration + 0.001:
                e(f"{tid}/{lid}: katman penceresi {where} süresini aşıyor "
                  f"({start}+{dur} > {container_duration})")
            if dur <= 0:
                e(f"{tid}/{lid}: katman penceresi sıfır ya da negatif")

            kind = layer.get("type")
            if kind == "shape":
                _require_role(e, tid, lid, palette, layer.get("colorRole"))
                grad = layer.get("gradient")
                if grad:
                    _require_role(e, tid, lid, palette, grad.get("from"))
                    _require_role(e, tid, lid, palette, grad.get("to"))
                    if grad.get("direction") not in (None, "up", "down", "left",
                                                     "right", "diagonal"):
                        e(f"{tid}/{lid}: bilinmeyen gradient yönü")
            elif kind == "text":
                _require_role(e, tid, lid, palette, layer.get("colorRole"))
                if layer.get("highlightColorRole"):
                    _require_role(e, tid, lid, palette, layer["highlightColorRole"])
                font = layer.get("font", {})
                if font.get("name") not in FONTS:
                    e(f"{tid}/{lid}: bilinmeyen font '{font.get('name')}'")
                size = font.get("size", 0)
                if not 0.014 <= size <= 0.22:
                    e(f"{tid}/{lid}: font boyutu {size} aralık dışı "
                      f"(0.014–0.22; küçüğü telefonda okunmuyor)")
                default = layer.get("default", {})
                if not default.get("tr") or not default.get("en"):
                    e(f"{tid}/{lid}: metin varsayılanı iki dilde olmalı")
                if not layer.get("key"):
                    e(f"{tid}/{lid}: text katmanının 'key' alanı zorunlu")
                text_boxes.append((lid, frame, start, start + dur,
                                   layer.get("alignment", "center")))
            elif kind == "mediaSlot":
                index = layer.get("slotIndex")
                if index in slot_indexes:
                    e(f"{tid}/{lid}: slotIndex {index} tekrar ediyor "
                      f"(sahneler dahil TÜM şablonda benzersiz olmalı)")
                slot_indexes.add(index)
                # `media` ve `mask` JSON'da opsiyonel; motor sırasıyla
                # photoOrVideo ve rect varsayıyor.
                media_kind = layer.get("media", "photoOrVideo")
                if media_kind not in ("photo", "video", "photoOrVideo"):
                    e(f"{tid}/{lid}: geçersiz media '{media_kind}'")
                if layer.get("mask", "rect") not in MASKS:
                    e(f"{tid}/{lid}: geçersiz mask '{layer.get('mask')}'")
                if layer.get("filter") and layer["filter"] not in FILTERS:
                    e(f"{tid}/{lid}: bilinmeyen filtre '{layer['filter']}'")
                if media_kind in ("video", "photoOrVideo"):
                    video_capable += 1
            elif kind == "lottie":
                for role in (layer.get("colorRemap") or {}).values():
                    _require_role(e, tid, lid, palette, role)
            else:
                e(f"{tid}/{lid}: bilinmeyen katman tipi '{kind}'")

            for anim in layer.get("animations", []):
                preset = anim.get("preset")
                if preset not in PRESETS:
                    e(f"{tid}/{lid}: motorun tanımadığı preset '{preset}'")
                if anim.get("role") not in ("in", "out", "loop"):
                    e(f"{tid}/{lid}: animasyon role'ü geçersiz")
                if anim.get("duration", 0) <= 0:
                    e(f"{tid}/{lid}: animasyon süresi sıfır")

        if video_capable > video_budget:
            e(f"{tid}: {where} {video_capable} video slotu taşıyor "
              f"(sınır {video_budget})")

        # Aynı anda sahnede olan iki metin bloğu üst üste binmemeli. Bu, göz
        # kontrolü yapılmadan yakalanabilecek EN sık düzen hatası.
        #
        # HİZA İSTİSNASI: sola yaslı ad + sağa yaslı fiyat (menü/ürün satırı)
        # aynı SATIRI paylaşır, frame'leri kesişir ama görüntüde çakışmaz —
        # her biri kendi kenarına yaslanır. Zıt hizalı çiftler atlanır.
        if strict:
            for i in range(len(text_boxes)):
                for j in range(i + 1, len(text_boxes)):
                    a_id, a_f, a_s, a_e, a_align = text_boxes[i]
                    b_id, b_f, b_s, b_e, b_align = text_boxes[j]
                    if a_e <= b_s + 0.05 or b_e <= a_s + 0.05:
                        continue  # zamanda kesişmiyor
                    if {a_align, b_align} == {"left", "right"}:
                        continue
                    if _overlap(a_f, b_f) > 0.5:
                        e(f"{tid}: '{a_id}' ve '{b_id}' metin blokları aynı anda "
                          f"üst üste biniyor")

    if scenes is not None:
        if doc.get("schemaVersion", 1) < 2:
            e(f"{tid}: 'scenes' için schemaVersion 2 gerekli")
        if not scenes:
            e(f"{tid}: en az bir sahne olmalı")
        scene_ids = set()
        for i, scene in enumerate(scenes):
            sid = scene.get("id")
            if sid in scene_ids:
                e(f"{tid}: sahne id'si tekrar ediyor '{sid}'")
            scene_ids.add(sid)
            if scene.get("duration", 0) <= 0:
                e(f"{tid}/{sid}: sahne süresi > 0 olmalı")
            transition = scene.get("transition")
            if transition and i < len(scenes) - 1:
                if transition.get("style") not in TRANSITIONS:
                    e(f"{tid}/{sid}: bilinmeyen geçiş '{transition.get('style')}'")
                limit = min(scene["duration"], scenes[i + 1]["duration"]) / 2
                if not 0 <= transition.get("duration", 0) <= limit + 1e-6:
                    e(f"{tid}/{sid}: geçiş süresi komşu sahnelerin yarısını aşıyor "
                      f"({transition.get('duration')} > {limit})")
            layers = scene.get("layers", [])
            media_layers = [l for l in layers if l.get("type") == "mediaSlot"]
            if media_layers:
                for l in layers:
                    if not opaque_shape(l):
                        continue
                    if opaque_full_frame(l):
                        e(f"{tid}/{l['id']}: montaj sahnesinde tam kadraj OPAK shape "
                          f"medyanın üstünü kapatır (shape'ler 2. geçişte medyanın "
                          f"ÜSTÜNE çizilir). Sahne zemini gereksiz — compositor "
                          f"paletteki background'ı zaten boyar.")
                        continue
                    # "Arkalık kart" düzeni: fotoğraftan BÜYÜK, onu tümüyle
                    # içine alan opak bir shape. Tasarımcının niyeti kartın
                    # fotoğrafın ARKASINDA durması (polaroid çerçevesi), ama
                    # montajda kart öne geçer. Böyle bir düzen klasik (v1)
                    # şablon olmalı.
                    #
                    # Medyanın ÜSTÜNDE duran küçük rozet/etiket/ayraç shape'leri
                    # bilerek öndedir ve sorun değil — bu yüzden yalnız shape
                    # medyadan büyükse uyarılır.
                    lf = l["frame"]
                    l_area = lf["width"] * lf["height"]
                    for m in media_layers:
                        mf = m["frame"]
                        m_area = mf["width"] * mf["height"]
                        if l_area > m_area * 1.05 and _overlap(lf, mf) > 0.9:
                            e(f"{tid}/{l['id']}: opak shape '{m['id']}' medya "
                              f"slotunu tamamen içine alıyor — montajda shape "
                              f"medyanın ÜSTÜNE çizildiği için fotoğraf görünmez. "
                              f"Bu düzen klasik (v1) şablon olmalı.")
                            break
            check_layers(layers, scene["duration"], f"sahne '{sid}'", 4)
        total = sum(s["duration"] for s in scenes)
        total -= sum(s.get("transition", {}).get("duration", 0) for s in scenes[:-1])
        for l in doc.get("layers", []):
            if opaque_full_frame(l):
                e(f"{tid}/{l['id']}: montajda global tam kadraj OPAK shape TÜM "
                  f"videoyu kapatır")
        check_layers(doc.get("layers", []), total, "global katmanlar", 0)
        if strict and not 3.0 <= total <= 20.0:
            e(f"{tid}: toplam süre {total:.1f} sn — hikâye videosu için 3–20 sn dışı")
    else:
        duration = doc.get("duration")
        if not duration:
            e(f"{tid}: sahnesiz şablon 'duration' taşımalı")
        else:
            # Klasik (CoreAnimationTool) yolda tek video slotu sınırı var.
            check_layers(doc.get("layers", []), duration, "şablon", 1)
            if strict and not 3.0 <= duration <= 20.0:
                e(f"{tid}: süre {duration} sn — hikâye videosu için 3–20 sn dışı")

    if slot_indexes and sorted(slot_indexes) != list(range(len(slot_indexes))):
        e(f"{tid}: slotIndex'ler 0'dan başlayıp ardışık olmalı "
          f"(editör şeridi '1,2,3…' diye numaralandırıyor) — {sorted(slot_indexes)}")

    return errors


def _require_role(e, tid, lid, palette, role):
    if role is None:
        e(f"{tid}/{lid}: colorRole eksik")
    elif role not in palette:
        e(f"{tid}/{lid}: palette'te olmayan rol '{role}'")


def _overlap(a, b):
    """İki frame'in kesişiminin küçük olanına oranı (0–1)."""
    ax1, ax2 = a["x"] - a["width"] / 2, a["x"] + a["width"] / 2
    ay1, ay2 = a["y"] - a["height"] / 2, a["y"] + a["height"] / 2
    bx1, bx2 = b["x"] - b["width"] / 2, b["x"] + b["width"] / 2
    by1, by2 = b["y"] - b["height"] / 2, b["y"] + b["height"] / 2
    w = max(0.0, min(ax2, bx2) - max(ax1, bx1))
    h = max(0.0, min(ay2, by2) - max(ay1, by1))
    inter = w * h
    smaller = min(a["width"] * a["height"], b["width"] * b["height"])
    return inter / smaller if smaller > 0 else 0.0


def dumps(doc):
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


# ------------------------------------------------------------- canlandırma

def enliven(doc):
    """Şablonu tek tek elden geçirmeden hareket sözlüğünü zenginleştirir.

    NEDEN VAR: katalog ölçüldüğünde şablonların %82'sinin tek sahneli olduğu ve
    tüm animasyonların %38'inin `fadeIn` olduğu çıktı — yani katalog teknik
    olarak doğru ama hissiyat olarak SLAYT. 127 şablonu tek tek yeniden yazmak
    yerine, motorun yeni preset'lerini kurallı bir geçişle uyguluyoruz:

      1. Çok kelimeli BAŞLIK (font >= 0.05) → `kineticWords` (kelime kelime).
      2. Tek kelimeli başlık → `punchIn` (sert yaklaşma).
      3. Rozet/çip görünümlü küçük şekiller → girişten sonra hafif `shake`.
      4. Şablon başına BİR metin katmanına `floatLoop` — kadraj hiç donmasın.

    Kural yalnız `fadeIn`/`slideIn` ile giren katmanlara dokunur; şablon yazarı
    bilerek başka bir preset seçtiyse (pop, bounce, typewriter, wipeReveal)
    ELLENMEZ. Bir şablon tamamen dışarıda kalsın isteniyorsa `Template.calm`
    True yapılır.
    """
    if doc.get("_calm"):
        doc.pop("_calm", None)
        return doc

    def layers_of(container):
        return container.get("layers", [])

    containers = doc.get("scenes") or [doc]
    float_budget = 1 if not doc.get("scenes") else 0   # yalnız tek sahnelilerde

    for container in containers:
        for layer in layers_of(container):
            anims = layer.get("animations", [])
            entry = [a for a in anims if a.get("role") == "in"]
            gentle = [a for a in entry if a.get("preset") in ("fadeIn", "slideIn")]

            if layer.get("type") == "text":
                size = layer.get("font", {}).get("size", 0)
                words = len((layer.get("default", {}).get("tr") or "").split())
                if gentle and size >= 0.05:
                    base = gentle[0]
                    delay, duration = base.get("delay", 0), base.get("duration", 0.6)
                    anims = [a for a in anims if a is not base]
                    if words > 1:
                        anims.insert(0, _anim("in", "kineticWords",
                                              max(duration, 0.9), delay, None,
                                              {"distance": 0.02}))
                    else:
                        anims.insert(0, _anim("in", "punchIn",
                                              min(duration, 0.55), delay, None,
                                              {"from": 1.5}))
                    layer["animations"] = anims

            elif layer.get("type") == "shape":
                frame = layer.get("frame", {})
                area = frame.get("width", 1) * frame.get("height", 1)
                # Rozet/çip: küçük, yuvarlak köşeli, girişi olan şekil.
                is_badge = (area < 0.06 and layer.get("cornerRadius", 0) > 0
                            and entry and layer.get("colorRole") != "background")
                has_loop = any(a.get("role") == "loop" for a in anims)
                if is_badge and not has_loop:
                    after = entry[0].get("duration", 0.6) + entry[0].get("delay", 0)
                    anims = anims + [_anim("loop", "shake", 1.4, after + 0.4, None,
                                           {"degrees": 2.0})]
                    layer["animations"] = anims

    # Kadraja sürekli can veren tek bir süzülen katman: en büyük metin.
    if float_budget:
        texts = [l for l in doc.get("layers", []) if l.get("type") == "text"
                 and not any(a.get("role") == "loop" for a in l.get("animations", []))]
        if texts:
            biggest = max(texts, key=lambda l: l.get("font", {}).get("size", 0))
            biggest.setdefault("animations", []).append(
                _anim("loop", "floatLoop", 2.6, 0.0, None,
                      {"distance": 0.006, "axis": "y"}))
    return doc
