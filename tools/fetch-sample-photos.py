#!/usr/bin/env python3
"""Vitrin örnek medyası için KAMU MALI / CC0 fotoğraf indirir.

NEDEN: `tools/samples/` klipleri galeri posterlerinin ve önizlemelerin İÇİNE
giriyor, yani hem uygulamayla hem CDN'le DAĞITILIYOR. Kaynağı belirsiz bir
görüntü buraya giremez (telif + kişilik hakkı + App Store içerik beyanı).
Sentetik üreteç bu yüzden vardı; ama gerçek fotoğrafla test edince şablonların
belirgin biçimde daha iyi göründüğü ölçüldü.

Çözüm: yalnız CC0 / kamu malı görselleri, LİSANS KÜNYESİYLE BİRLİKTE indir.
Her dosyanın kaynağı, yazarı ve lisansı `CREDITS.md`ye yazılır — hak zinciri
belgelenmiş olur.

İKİ AŞAMALI: indirilen her kare doğrudan vitrine girmiyor. Önce `candidates/`
klasörüne iner (künyesi `candidates/manifest.json`), gözle elenir, sonra
`--promote` ile `source/`e taşınır. Bunun sebebi acı bir deneyim: eskiden
doğrudan `source/`e iniyordu ve elenmesi gereken kareler (cihaz filigranı,
tanınabilir yüz) bir sonraki poster turunda vitrine sızıyordu.

    python3 tools/fetch-sample-photos.py --per 3        # adayları indir
    python3 tools/detect-faces.swift tools/samples/candidates   # yüz taraması
    # gözle ele → candidates/ACCEPTED.txt (satır başına dosya adı)
    python3 tools/fetch-sample-photos.py --promote

Sonra:
    cd TemplateKit && swift run -c release templatekit-assets --make-samples
    swift run -c release templatekit-assets
"""

import argparse
import json
import pathlib
import shutil
import subprocess
import time
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
SAMPLES = ROOT / "tools" / "samples"
OUT = SAMPLES / "source"
STAGE = SAMPLES / "candidates"
API = "https://commons.wikimedia.org/w/api.php"
# İKİNCİ KAYNAK: Commons'ın CC0 havuzu manzara/mimari ağırlıklı; yaşam tarzı
# kareleri (çalışan eller, salon, spor, kutlama) orada ya yok ya CC BY.
# Openverse anahtar istemiyor ve rawpixel/stocksnap gibi YÜKSEK ÇÖZÜNÜRLÜKLÜ
# CC0 koleksiyonlarını da tarıyor.
OPENVERSE = "https://api.openverse.org/v1/images/"

# TÜR ADI = DOSYA ADININ İLK PARÇASI. Bu bir isimlendirme zevki değil, arayüz:
# `SampleClips.generatePhotoClips` adı `sample-NN-<tür>.mp4`ya taşıyor,
# `MediaPool.order(for:)` de kategoriyi o türle eşleştiriyor. Yeni bir tür
# eklersen Assets.swift'teki `wanted` listelerine de ekle, yoksa kare yalnız
# yedek havuzda kalır.
#
# `-painting -oil` şart: "mountain landscape sunset" araması Commons'ta önce
# TABLOLARI getiriyor (Dahl, Fragonard, de Molijn — üçü birden geldi).
NEGATIVE = "-painting -oil -drawing -engraving -illustration -poster -map"

# (Commons sorgusu, Openverse sorgusu). Commons önce denenir — künyesi ve
# çözünürlüğü daha güvenilir; kota dolmazsa Openverse tamamlar.
THEMES = {
    # yemek
    "food":      ("plated food dish restaurant photograph -menu", "plated food"),
    "plate":     ("breakfast table top view photograph", "breakfast flat lay"),
    "dessert":   ("cake dessert pastry photograph", "dessert cake"),
    "cafe":      ("cafe interior coffee shop photograph", "cafe interior"),
    # mekân / gezi
    "city":      ("city street evening photograph -1920s -postcard", "city street night"),
    "nature":    ("mountain landscape photograph", "mountain landscape"),
    "sunset":    ("sunset sky clouds photograph", "sunset sky"),
    "ocean":     ("sea beach waves photograph", "beach waves"),
    "forest":    ("forest trees path photograph", "forest path"),
    # emlak
    "room":      ("living room interior furniture photograph", "living room"),
    "house":     ("house exterior facade garden photograph", "house exterior"),
    # moda / doku
    "fabric":    ("folded fabric textile photograph", "folded fabric"),
    "texture":   ("knit wool texture close up photograph", "wool texture"),
    "clothes":   ("clothes rack hangers boutique photograph", "clothes rack"),
    "shoes":     ("shoes pair studio photograph", "sneakers"),
    # İNSAN VARLIĞI — yüzsüz: vitrin sorununun asıl çözümü bu türler.
    # Sorgular BİLEREK ele/omuza odaklı: "chef cooking" gibi bir sorgu yüz
    # getiriyor ve yüz taraması hepsini eliyor (boşa indirme).
    "hands":     ("hands holding photograph", "kneading dough"),
    "dough":     ("bread dough baking photograph", "kneading dough"),
    "pour":      ("pouring coffee cup hands photograph", "pouring coffee"),
    "nails":     ("manicure nails hand close up photograph", "manicure"),
    "hair":      ("long hair back view photograph", "long hair"),
    "write":     ("hand writing notebook pen photograph", "writing notebook"),
    # güzellik / bakım
    "salon":     ("hairdresser salon interior chair photograph", "hair salon"),
    "spa":       ("spa towels candles stones photograph", "spa towels"),
    "makeup":    ("cosmetics makeup brushes photograph", "makeup brushes"),
    # spor
    "gym":       ("gym dumbbells equipment photograph", "gym dumbbells"),
    "run":       ("running shoes track photograph", "running shoes"),
    "yoga":      ("yoga mat studio photograph", "yoga mat"),
    # iş / eğitim
    "workspace": ("desk workspace notebook laptop photograph", "desk laptop"),
    "books":     ("books stack library photograph", "books stack"),
    # müzik
    "music":     ("guitar instrument studio photograph", "acoustic guitar"),
    "vinyl":     ("vinyl record turntable headphones photograph", "vinyl turntable"),
    # kutlama
    "flowers":   ("flower bouquet arrangement photograph", "flower bouquet"),
    "party":     ("balloons confetti celebration photograph", "confetti balloons"),
    "candle":    ("candles lights bokeh night photograph", "candles bokeh"),
    # diğer
    "pet":       ("cat dog pet photograph", "cat"),
    "shop":      ("shop shelf retail display photograph", "retail shelf"),
}

# İKİNCİ TUR COMMONS SORGULARI. Ölçülen gerçek: yüksek çözünürlüklü CC0 havuzu
# pratikte YALNIZ Commons. Openverse'ün büyük sağlayıcıları dağıtım boyunu
# kısıyor (flickr 1024, stocksnap 960, rawpixel 1300 yükseklik) — künyede 5760
# yazsa bile. Dolayısıyla bir tür boş kaldığında çare Openverse değil, Commons'a
# BAŞKA KELİMELERLE sormak.
#
# KELİME SEÇİMİ SONUCU BELİRLİYOR (ölçüldü): "gym dumbbells equipment
# photograph" sıfır sonuç verirken "gym fitness interior photograph" 5862×5100
# CC0 getiriyor. Bir tür boş kaldığında önce SORGUYU değiştir; havuz sanıldığı
# kadar dar değil. Aşağıdakilerin hepsi tek tek denenip sonuç verdiği görülerek
# yazıldı.
ALT_COMMONS = {
    "ocean":     "ocean waves coast photograph",
    "city":      "urban skyline buildings photograph",
    "fabric":    "fabric cloth photograph",
    "texture":   "wood texture background photograph",
    "clothes":   "clothing shop rack photograph",
    "shoes":     "shoes photograph",
    "hands":     "hands holding photograph",
    "pour":      "coffee pouring photograph",
    "nails":     "nail polish manicure photograph",
    "salon":     "hairdressing salon photograph",
    "spa":       "spa wellness interior photograph",
    "makeup":    "makeup cosmetics photograph",
    "gym":       "gym fitness interior photograph",
    "yoga":      "yoga studio photograph",
    "workspace": "office desk workspace photograph",
    "vinyl":     "vinyl records photograph",
    "party":     "balloons party decoration photograph",
    "candle":    "candles photograph",
    "shop":      "shop interior shelves photograph",
    "food":      "burger pizza plate photograph",
    "cafe":      "coffee shop counter photograph",
    "dough":     "bread dough baking photograph",
}

# Yalnız bunlar kabul: yeniden dağıtımı ve ticari kullanımı koşulsuz serbest.
# CC BY / BY-SA BİLEREK DIŞARIDA: künye zorunluluğu uygulamaya bir "lisanslar"
# ekranı borcu getirir ve şablon posterinin üstünde künye gösterilemez.
ALLOWED = {"cc0", "public domain", "pd", "cc-zero", "no restrictions"}

# Klip 1080×1920 DİKEY üretiliyor. Manzara bir kareden 9:16 kırpınca kullanılan
# genişlik = min(w, h*9/16); bu değer 1000'in altına inerse poster gözle görülür
# biçimde yumuşuyor. Kaynağı bu eşiğe göre eliyoruz — indirdikten sonra değil.
MIN_CROP_WIDTH = 1000
TARGET_HEIGHT = 1920

# Lisans yeterli DEĞİL: elle elenmiş dosyalar bir daha inmesin (bkz. REJECTED.txt
# — cihaz filigranı, tanınabilir insan, tablo…). Bu liste küratörlüğün kalıcı
# hafızası; dosyayı elle silmek yetmiyor, sonraki koşu geri indiriyordu.
REJECTED_FILE = OUT / "REJECTED.txt"

# İndirme `curl` ile yapılıyor: bu makinedeki Python kurulumunda kök sertifika
# deposu yok (`CERTIFICATE_VERIFY_FAILED`), curl sistem deposunu kullanıyor.
UA = "story-template-app/1.0 (sample media fetcher)"


def rejected_entries():
    """(başlık parçası, sebep) çiftleri."""
    if not REJECTED_FILE.exists():
        return []
    entries = []
    for line in REJECTED_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        needle, _, reason = line.partition("|")
        entries.append((needle.strip(), reason.strip()))
    return entries


def _curl(url, binary=False):
    result = subprocess.run(
        ["curl", "-sL", "--max-time", "90", "-A", UA, url],
        capture_output=True, check=True)
    return result.stdout if binary else result.stdout.decode("utf-8")


def download(url, waits=(5, 15, 30, 60)):
    """Görseli indir; 429'da geri çekil.

    upload.wikimedia.org ardışık indirmede HTTP 429 döndürüyor ve gövde olarak
    2 KB'lik bir HATA SAYFASI veriyor — curl bunu başarı sayıyor. Boyuta bakıp
    tekrar denemezsek kare sessizce kaybolur (ilk koşuda 9 kare böyle düştü).
    """
    # rawpixel `editor_1024` yolunu WEBP olarak sunuyor; `image_1300` aynı kareyi
    # JPEG ve daha büyük veriyor. Başka bir boyut adı 403 dönüyor.
    url = url.replace("/editor_1024/", "/image_1300/")
    for wait in waits:
        data = _curl(url, binary=True)
        if len(data) >= 20_000 and data[:2] in (b"\xff\xd8", b"\x89P"):
            return data
        print(f"    (indirme reddedildi, {wait} sn bekleniyor)")
        time.sleep(wait)
    raise ValueError("indirilemedi (hız sınırı?)")


def colorful(path, floor=0.06):
    """Kare siyah-beyaz DEĞİL mi? — doygunluğun 90. yüzdeliği.

    Commons'ın CC0 havuzunun büyük kısmı TARİHÎ TARAMA. Bu kapı onların yalnız
    bir bölümünü — GERÇEK siyah-beyazı — yakalar; ölçüldü:

        gerçek siyah-beyaz  0,000
        sepya tonlanmış     0,204
        gerçek renkli kare  0,118 – 0,74   (`city-3` vitrinde ve 0,118)

    Yani eşik yükseltilemez: SEPYA ile SOLGUN RENKLİ ayırt edilemiyor, ve
    0,16 denendiğinde beyaz zeminli ürün kareleri (makyaj paleti, tabak, elde
    buket) yanlışlıkla elendi — 50 kare böyle kaybedildi. Sepya/tarihî tarama
    işini `recent()` yılı ve gözle eleme yapar; burada yalnız kesin olan
    reddedilir. ORTALAMA doygunluk hiç kullanılmamalı (nötr zemin onu da
    siyah-beyaz gösteriyor).
    """
    from PIL import Image
    image = Image.open(path).convert("RGB")
    image.thumbnail((160, 160))
    saturations = sorted((max(p) - min(p)) / 255 for p in image.getdata())
    return saturations[int(len(saturations) * 0.9)] >= floor


def recent(meta, earliest=1995):
    """Commons üstverisindeki çekim yılı — tarihî taramaları indirmeden eler.

    `DateTimeOriginal` çoğu tarihî dosyada dolu ("1905", "circa 1920"). Yıl
    okunamıyorsa kare GEÇER: eksik üstveri yüzünden iyi kare atmaktansa gözle
    elemek daha ucuz.
    """
    import re
    for field in ("DateTimeOriginal", "DateTime"):
        value = (meta.get(field, {}) or {}).get("value") or ""
        years = re.findall(r"(1[6-9]\d\d|20[0-4]\d)", str(value))
        if years:
            return max(int(year) for year in years) >= earliest
    return True


def measure(path):
    """İNEN dosyanın gerçek pikseli — üstverininki değil.

    Servislerin bildirdiği boyut yalanabiliyor: stocksnap künyede 5760×3840
    diyor ama 960×640 gönderiyor, Commons küçük dosyada thumb yerine aslını
    veriyor. 12 aday bu yüzden "yeterli" sanılıp indirildi ve poster ölçeğinde
    bulanık kalırdı. Tek güvenilir kapı budur.
    """
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                         capture_output=True, text=True).stdout
    values = dict(line.strip().split(": ") for line in out.splitlines() if ": " in line)
    width, height = int(values.get("pixelWidth", 0)), int(values.get("pixelHeight", 0))
    return width, height, min(width, height * 9 / 16)


def _json(url, waits=(3, 6, 9)):
    """Hız sınırına takılınca geri çekil.

    Commons 20 aramadan sonra HTML hata sayfası döndürmeye başlıyor (JSON
    değil); ilk koşuda 32 temanın 12'si sessizce bu yüzden boş kaldı.
    """
    for wait in waits:
        text = _curl(url)
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            print(f"    (yanıt JSON değil, {wait} sn bekleniyor)")
            time.sleep(wait)
    raise RuntimeError("servis JSON döndürmedi (hız sınırı?)")


def api(params):
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json"})
    time.sleep(1.0)                 # nazik olmak: paylaşılan ücretsiz servis
    return _json(url)


def acceptable(meta):
    license_name = (meta.get("LicenseShortName", {}).get("value") or "").lower()
    return any(token in license_name for token in ALLOWED)


def big_enough(info):
    width, height = info.get("width") or 0, info.get("height") or 0
    if not width or not height:
        return False
    return min(width, height * 9 / 16) >= MIN_CROP_WIDTH and height >= 1200


def _plain(html):
    """extmetadata alanları HTML döndürüyor; künyeye düz metin yazalım."""
    out, depth = [], 0
    for char in html:
        if char == "<":
            depth += 1
        elif char == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(char)
    return " ".join("".join(out).split())[:120]


def search(term, limit, rejected=(), seen=()):
    """Konuya göre ara, sonra LİSANSA, ÇÖZÜNÜRLÜĞE ve eleme listesine göre ele."""
    data = api({
        "action": "query",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {term}",
        "gsrnamespace": 6,
        "gsrlimit": limit * 12,         # çoğu eleneceği için geniş çek
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|size",
        # Yükseklikten ölçekliyoruz: 9:16 kırpım genişliği yükseklikten türüyor,
        # `iiurlwidth` ile inen manzara kare kırpılınca 600 px'e düşüyordu.
        "iiurlheight": TARGET_HEIGHT,
    })
    found = []
    for page in (data.get("query", {}).get("pages") or {}).values():
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata", {})
        title = page.get("title", "")
        if title in seen:
            continue
        if not acceptable(meta):
            continue
        if not recent(meta):
            continue
        if not big_enough(info):
            continue
        skip = next((r for n, r in rejected if n.lower() in title.lower()), None)
        if skip is not None:
            print(f"  elendi (liste): {title[:60]}… — {skip}")
            continue
        url = info.get("thumburl") or info.get("url")
        if not url:
            continue
        found.append({
            "title": title,
            "url": url.split("?")[0],
            "descriptionurl": info.get("descriptionurl", ""),
            "license": meta.get("LicenseShortName", {}).get("value", ""),
            "author": _plain(meta.get("Artist", {}).get("value", "")),
            "width": info.get("width"),
            "height": info.get("height"),
            "original": info.get("url", "").split("?")[0],
            "provider": "wikimedia",
        })
        if len(found) >= limit:
            break
    return found


def search_openverse(term, limit, rejected=(), seen=(), pages=3):
    """Aynı eleme kuralları, Openverse (rawpixel / stocksnap / flickr CC0)."""
    found, items = [], []
    for page in range(1, pages + 1):
        url = OPENVERSE + "?" + urllib.parse.urlencode({
            # ANONİM SINIR: sayfa başına en fazla 20. Fazlasını isteyince servis
            # 200 ile `{"detail": "page_size may not exceed 20…"}` döndürüyor —
            # GEÇERLİ JSON olduğu için hata sessizce "sonuç yok"a dönüşüyordu
            # (18 tema bir tur boyunca bu yüzden boş kaldı).
            "q": term, "license": "cc0", "page_size": 20, "page": page,
        })
        # Anonim kota: DAKİKADA 20 istek (günlük 200).
        time.sleep(4.0)
        data = _json(url, waits=(20, 40, 60))
        if "results" not in data:
            print(f"    (openverse: {data.get('detail', data)})")
            break
        items += data["results"]
        if len(items) >= limit * 12 or not data.get("page_count") or page >= data["page_count"]:
            break
    for item in items:
        title = item.get("title") or item.get("id", "")
        if title in seen:
            continue
        if not big_enough(item):
            continue
        # DAĞITIM BOYU KÜNYEDEN BAĞIMSIZ: flickr en fazla 1024, stocksnap 960,
        # rawpixel 1300 gönderiyor (künyede 5760 yazsa bile). Bu boylarda YATAY
        # bir kare 9:16 kırpımda 1000 px'in altına düşer — indirmeden eleyelim.
        # DİKEY kare aynı boyda geçiyor (1300×1950 → kırpım 1097).
        if (item.get("width") or 0) >= (item.get("height") or 1) and \
                item.get("source") in {"flickr", "stocksnap", "rawpixel"}:
            continue
        skip = next((r for n, r in rejected if n.lower() in title.lower()), None)
        if skip is not None:
            print(f"  elendi (liste): {title[:60]}… — {skip}")
            continue
        if not item.get("url"):
            continue
        found.append({
            "title": title,
            "url": item["url"],
            "descriptionurl": item.get("foreign_landing_url", ""),
            "license": f"CC0 {item.get('license_version', '')}".strip(),
            "author": (item.get("creator") or "")[:120],
            "width": item.get("width"),
            "height": item.get("height"),
            "provider": item.get("source", "openverse"),
        })
        if len(found) >= limit:
            break
    return found


def fetch(per, only=None):
    STAGE.mkdir(parents=True, exist_ok=True)
    rejected = rejected_entries()
    manifest_file = STAGE / "manifest.json"
    # Tek tema yenilenirken önceki künye korunur (hız sınırı yüzünden koşuyu
    # bölmek gerekebiliyor).
    manifest = json.loads(manifest_file.read_text()) if manifest_file.exists() else {}
    seen = {item["title"] for item in manifest.values()}
    total = 0
    for kind, (commons_term, openverse_term) in THEMES.items():
        if only and kind not in only:
            continue
        results = []
        try:
            results = search(f"{commons_term} {NEGATIVE}", per, rejected, seen)
        except Exception as error:                      # ağ/servis hatası
            print(f"  {kind}: Commons atlandı ({error})")
        if len(results) < per and kind in ALT_COMMONS:
            try:
                results += search(f"{ALT_COMMONS[kind]} {NEGATIVE}", per - len(results),
                                  rejected, seen | {r["title"] for r in results})
            except Exception as error:
                print(f"  {kind}: Commons (2. sorgu) atlandı ({error})")
        if len(results) < per:
            try:
                extra = search_openverse(openverse_term, per - len(results),
                                         rejected, seen | {r["title"] for r in results})
                results += extra
            except Exception as error:
                print(f"  {kind}: Openverse atlandı ({error})")
        if not results:
            print(f"  {kind}: eşleşme yok (lisans/çözünürlük eledi)")
        # Numara var olanın ARDINDAN devam eder: `--only` ile bir temayı
        # tamamlarken `food-1.jpg`in üstüne yazıp önceki kareyi kaybetmeyelim.
        already = sum(1 for name in manifest if name.rsplit("-", 1)[0] == kind)
        for index, item in enumerate(results, start=already + 1):
            name = f"{kind}-{index}.jpg"
            try:
                time.sleep(0.5)
                (STAGE / name).write_bytes(download(item["url"]))
                width, height, crop = measure(STAGE / name)
                # Thumb küçük geldiyse ASLINI dene (yalnız Commons'ta var).
                if crop < MIN_CROP_WIDTH and item.get("original"):
                    print(f"    ({name}: thumb {width}×{height} küçük, aslı deneniyor)")
                    (STAGE / name).write_bytes(download(item["original"]))
                    width, height, crop = measure(STAGE / name)
                if crop < MIN_CROP_WIDTH:
                    (STAGE / name).unlink()
                    print(f"  {name}: ELENDİ — inen kare {width}×{height}, "
                          f"9:16 kırpımı {crop:.0f} px")
                    continue
                if not colorful(STAGE / name):
                    (STAGE / name).unlink()
                    print(f"  {name}: ELENDİ — siyah-beyaz/sepya tarama")
                    continue
                item["downloaded"] = [width, height]
            except Exception as error:
                print(f"  {name}: indirilemedi ({error})")
                continue
            seen.add(item["title"])
            manifest[name] = item
            total += 1
            print(f"  {name}  {item['license']}  {item['width']}×{item['height']}"
                  f"  ({item['provider']})")
    manifest_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"\n{total} aday → {STAGE.relative_to(ROOT)}")
    print("Sırada: yüz taraması + gözle eleme → ACCEPTED.txt → --promote")


#: `source/` DEPOYA GİRİYOR, `candidates/` girmiyor. Commons kareleri
#: 4000–6600 piksel iniyor; örnek klipler 1080×1920 üretiliyor. Ham hâlleriyle
#: 57 fotoğraf 154 MB ediyordu — public bir depoda taşınacak ölü ağırlık.
#: 2160 uzun kenar, Ken Burns'ün 1,1× yakınlaştırmasına bile fazlasıyla yetiyor
#: ve toplam 38 MB'a iniyor. Küçültme KOPYALAMA ANINDA yapılır: `promote()`
#: `source/`ü her seferinde sıfırdan kuruyor, sonradan elle küçültmek bir
#: sonraki promote'ta geri alınırdı.
MAX_EDGE = 2160
JPEG_QUALITY = 88


def shrink(source, target):
    """Adayı en fazla `MAX_EDGE` uzun kenarla `source/`e yazar."""
    from PIL import Image                       # yalnız promote yolunda gerekli
    image = Image.open(source).convert("RGB")
    width, height = image.size
    if max(width, height) > MAX_EDGE:
        scale = MAX_EDGE / max(width, height)
        image = image.resize((round(width * scale), round(height * scale)),
                             Image.LANCZOS)
    image.save(target, "JPEG", quality=JPEG_QUALITY,
               optimize=True, progressive=True)


def promote():
    """ACCEPTED.txt'teki kareleri `source/`e taşı ve künyeyi yeniden yaz."""
    manifest = json.loads((STAGE / "manifest.json").read_text())
    accepted_file = STAGE / "ACCEPTED.txt"
    if not accepted_file.exists():
        raise SystemExit(f"{accepted_file} yok — önce adayları gözle ele.")
    accepted = [line.strip() for line in accepted_file.read_text().splitlines()
                if line.strip() and not line.startswith("#")]
    missing = [n for n in accepted if n not in manifest]
    if missing:
        raise SystemExit(f"künyesi olmayan dosya: {missing}")

    OUT.mkdir(parents=True, exist_ok=True)
    # `source/` TAMAMEN yeniden kuruluyor: elenen bir kare klasörde kalırsa
    # bir sonraki `--make-samples` onu yine klibe çevirir.
    for old in OUT.glob("*.jpg"):
        old.unlink()
    # Türe göre yeniden numaralandır: ACCEPTED.txt'te "food-2, food-5" kalmışsa
    # `source/` içinde food-1, food-2 olsun — numara boşluğu bir anlam taşımıyor.
    counters, promoted = {}, []
    for name in accepted:
        kind = name.split("-")[0]
        counters[kind] = counters.get(kind, 0) + 1
        target = f"{kind}-{counters[kind]}.jpg"
        shrink(STAGE / name, OUT / target)
        promoted.append((target, manifest[name]))

    rejected = rejected_entries()
    lines = ["# Örnek medya künyesi",
             "",
             "Bu klasördeki görseller `templatekit-assets --make-samples` ile",
             "örnek kliplere dönüşür ve galeri posterlerinin içine girer.",
             "HEPSİ kamu malı ya da CC0 — yeniden dağıtım ve ticari kullanım serbest.",
             "Dosya eklerken lisansını buraya yazmadan ekleme.",
             "",
             "DOSYA ADI ARAYÜZDÜR: ilk parça (`food-1.jpg` → `food`) klibin türü",
             "olur ve kategori eşleştirmesi onu okur (`Assets.swift`, `wanted`).",
             "",
             "Lisans YETMİYOR: cihaz filigranı/tarih damgası taşıyan, TANINABİLİR",
             "YÜZ içeren, okunur marka/afiş metni olan, tablo ya da tarihî",
             "siyah-beyaz kareler vitrine girmez. Yüz taraması otomatik",
             "(`tools/detect-faces.swift`), gerisi gözle. Elenenler",
             "`REJECTED.txt`te; betik onları bir daha indirmiyor.",
             "",
             f"Bu dosya `fetch-sample-photos.py --promote` ile ÜRETİLDİ — {len(promoted)} kare.",
             ""]
    lines += [f"- {needle} — {reason}" for needle, reason in rejected] or ["- (liste boş)"]
    lines.append("")
    for name, item in promoted:
        lines += [f"## {name}",
                  f"- Kaynak: {item['descriptionurl'] or item['url']}",
                  f"- Lisans: {item['license']}",
                  f"- Yazar: {item['author'] or 'belirtilmemiş'}",
                  ""]
    (OUT / "CREDITS.md").write_text("\n".join(lines))
    print(f"{len(promoted)} kare → {OUT.relative_to(ROOT)}  (künye: CREDITS.md)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--per", type=int, default=3, help="tema başına adet")
    parser.add_argument("--only", help="yalnız bu temalar (virgülle)")
    parser.add_argument("--promote", action="store_true",
                        help="ACCEPTED.txt'teki adayları source/'e taşı")
    args = parser.parse_args()
    only = {t.strip() for t in args.only.split(",")} if args.only else None
    promote() if args.promote else fetch(args.per, only)


if __name__ == "__main__":
    main()
