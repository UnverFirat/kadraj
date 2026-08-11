#!/usr/bin/env python3
"""templates/assets/confetti.json — konfeti animasyonunu üretir (bodymovin JSON).

NEDEN ÜRETİYORUZ, HAZIR VARLIK İNDİRMİYORUZ: hazır Lottie kütüphaneleri
(LottieFiles vb.) lisans zinciri getiriyor — uygulama mağazaya çıkarken her
varlığın hakkını taşımak gerekiyor. Müzikte aldığımız kararın aynısı: varlığı
dosya olarak değil TARİF olarak tut, kendi kodumuzla üret. Konfeti geometrik
bir animasyon; elle 28 katman yazmak yerine burada döngüyle üretilmesi hem
kısa hem de "parça sayısı/hız/renk" gibi parametreleri oynanabilir kılıyor.

Renkler ŞABLONDAN gelir: burada üç yer tutucu renk kullanılır, şablonun
`colorRemap` alanı bunları palet rollerine bağlar (LottieAssetRewriter ham
JSON'da değiştirir). Yani aynı varlık her şablonun renk şemasına uyar.

Kullanım:  python3 tools/make-lottie-confetti.py
"""
import json
import math
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "templates" / "assets" / "confetti.json"

WIDTH, HEIGHT = 1080, 1920
FPS = 30
DURATION_FRAMES = 90          # 3 sn
PIECES = 28

# Yer tutucu renkler — şablon `colorRemap` ile palet rolüne bağlar.
# (0–1 aralığı, bodymovin biçimi.)
PALETTE = [
    (1.0, 0.302, 0.427),      # #FF4D6D  → accent
    (1.0, 0.820, 0.400),      # #FFD166  → highlight
    (1.0, 1.0, 1.0),          # #FFFFFF  → surface
]


def keyframes(values):
    """[(frame, [values...]), ...] → bodymovin keyframe dizisi (lineer)."""
    return [{"t": frame, "s": list(value)} for frame, value in values]


def piece(index, rng):
    """Tek konfeti parçası: yukarıdan düşen, dönen, sonunda solan dikdörtgen."""
    start = rng.randint(0, 24)                    # kademeli giriş
    fall = rng.randint(48, 78)                    # düşüş süresi (kare)
    end = min(start + fall, DURATION_FRAMES)

    x0 = rng.uniform(0.04, 0.96) * WIDTH
    drift = rng.uniform(-0.14, 0.14) * WIDTH      # yana savrulma
    y0 = rng.uniform(-0.18, -0.02) * HEIGHT
    y1 = rng.uniform(0.85, 1.15) * HEIGHT

    width = rng.uniform(0.012, 0.026) * WIDTH
    height = width * rng.uniform(1.1, 2.2)
    spin = rng.choice([-1, 1]) * rng.uniform(180, 900)
    tilt = rng.uniform(0, 360)
    color = PALETTE[index % len(PALETTE)]

    return {
        "ddd": 0,
        "ind": index + 1,
        "ty": 4,                                   # shape layer
        "nm": f"piece-{index + 1}",
        "sr": 1,
        "ks": {
            # Son 8 karede sönerek çıkar — kesik biten parça göze batıyor.
            "o": {"a": 1, "k": keyframes([
                (start, [0]), (start + 4, [100]),
                (max(start + 5, end - 8), [100]), (end, [0]),
            ])},
            "r": {"a": 1, "k": keyframes([(start, [tilt]), (end, [tilt + spin])])},
            "p": {"a": 1, "k": keyframes([
                (start, [x0, y0]),
                # Ortada hafif yay: düz çizgide düşen konfeti sahte duruyor.
                ((start + end) // 2, [x0 + drift * 0.6, (y0 + y1) / 2]),
                (end, [x0 + drift, y1]),
            ])},
            "a": {"a": 0, "k": [0, 0, 0]},
            "s": {"a": 0, "k": [100, 100, 100]},
        },
        "ao": 0,
        "shapes": [{
            "ty": "gr",
            "nm": "shape",
            "it": [
                {"ty": "rc", "d": 1,
                 "s": {"a": 0, "k": [round(width, 2), round(height, 2)]},
                 "p": {"a": 0, "k": [0, 0]},
                 "r": {"a": 0, "k": round(min(width, height) * 0.35, 2)}},
                {"ty": "fl", "nm": "fill", "r": 1,
                 "c": {"a": 0, "k": [color[0], color[1], color[2], 1]},
                 "o": {"a": 0, "k": 100}},
                {"ty": "tr",
                 "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
                 "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
                 "o": {"a": 0, "k": 100}},
            ],
        }],
        "ip": start,
        "op": DURATION_FRAMES,
        "st": 0,
        "bm": 0,
    }


def main():
    # Sabit tohum: üreteci yeniden çalıştırmak aynı animasyonu vermeli,
    # yoksa her çalıştırmada şablonun görüntüsü sessizce değişir.
    rng = random.Random(20260722)
    animation = {
        "v": "5.7.4",
        "fr": FPS,
        "ip": 0,
        "op": DURATION_FRAMES,
        "w": WIDTH,
        "h": HEIGHT,
        "nm": "confetti",
        "ddd": 0,
        "assets": [],
        "layers": [piece(i, rng) for i in range(PIECES)],
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(animation, separators=(",", ":")) + "\n")
    size_kb = OUT.stat().st_size / 1024
    print(f"{OUT.relative_to(ROOT)} — {PIECES} parça, "
          f"{DURATION_FRAMES / FPS:.1f} sn, {size_kb:.0f} KB")


if __name__ == "__main__":
    main()
