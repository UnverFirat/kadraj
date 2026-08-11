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

    python3 tools/fetch-sample-photos.py            # varsayılan temalar
    python3 tools/fetch-sample-photos.py --per 3    # tema başına adet

Sonra:
    cd TemplateKit && swift run -c release templatekit-assets --make-samples
    swift run -c release templatekit-assets
"""

import argparse
import json
import pathlib
import subprocess
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "tools" / "samples" / "source"
API = "https://commons.wikimedia.org/w/api.php"

# Kompozisyon çeşitliliği için temalar (SampleClipGenerator'daki altı
# kompozisyonun gerçek karşılıkları).
# `-painting -oil` şart: "mountain landscape sunset" araması Commons'ta önce
# TABLOLARI getiriyor (Dahl, Fragonard, de Molijn — üçü birden geldi).
THEMES = {
    "food":     "plated food dish restaurant -painting -menu",
    "cafe":     "cafe interior coffee shop -painting -people",
    "city":     "city street evening skyline -painting -1920s -postcard",
    "nature":   "mountain landscape sunset photograph -painting -oil -drawing -engraving",
    "texture":  "fabric texture close up -painting",
    "workspace": "desk workspace notebook -painting",
}

# Yalnız bunlar kabul: yeniden dağıtımı ve ticari kullanımı koşulsuz serbest.
ALLOWED = {"cc0", "public domain", "pd", "cc-zero"}

# Lisans yeterli DEĞİL: elle elenmiş dosyalar bir daha inmesin (bkz. REJECTED.txt
# — cihaz filigranı, tanınabilir insan, tablo…). Bu liste küratörlüğün kalıcı
# hafızası; dosyayı elle silmek yetmiyor, sonraki koşu geri indiriyordu.
REJECTED_FILE = OUT / "REJECTED.txt"


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


# İndirme `curl` ile yapılıyor: bu makinedeki Python kurulumunda kök sertifika
# deposu yok (`CERTIFICATE_VERIFY_FAILED`), curl sistem deposunu kullanıyor.
UA = "story-template-app/1.0 (sample media fetcher)"


def _curl(url, binary=False):
    result = subprocess.run(
        ["curl", "-sL", "--max-time", "60", "-A", UA, url],
        capture_output=True, check=True)
    return result.stdout if binary else result.stdout.decode("utf-8")


def api(params):
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json"})
    return json.loads(_curl(url))


def acceptable(meta):
    license_name = (meta.get("LicenseShortName", {}).get("value") or "").lower()
    return any(token in license_name for token in ALLOWED)


def search(term, limit, rejected=()):
    """Konuya göre ara, sonra LİSANSA ve ELEME LİSTESİNE göre ele."""
    data = api({
        "action": "query",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {term}",
        "gsrnamespace": 6,
        "gsrlimit": limit * 8,          # çoğu eleneceği için geniş çek
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": 1080,
    })
    found = []
    for page in (data.get("query", {}).get("pages") or {}).values():
        info = (page.get("imageinfo") or [{}])[0]
        meta = info.get("extmetadata", {})
        if not acceptable(meta):
            continue
        title = page.get("title", "")
        skip = next((r for n, r in rejected if n.lower() in title.lower()), None)
        if skip is not None:
            print(f"  elendi (liste): {title[:60]}… — {skip}")
            continue
        url = info.get("thumburl") or info.get("url")
        if not url:
            continue
        found.append({
            "title": page.get("title", ""),
            "url": url.split("?")[0],
            "descriptionurl": info.get("descriptionurl", ""),
            "license": meta.get("LicenseShortName", {}).get("value", ""),
            "author": _plain(meta.get("Artist", {}).get("value", "")),
        })
        if len(found) >= limit:
            break
    return found


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--per", type=int, default=2, help="tema başına adet")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    rejected = rejected_entries()
    credits = ["# Örnek medya künyesi",
               "",
               "Bu klasördeki görseller `templatekit-assets --make-samples` ile",
               "örnek kliplere dönüşür ve galeri posterlerinin içine girer.",
               "HEPSİ kamu malı ya da CC0 — yeniden dağıtım ve ticari kullanım serbest.",
               "Dosya eklerken lisansını buraya yazmadan ekleme.",
               "",
               "Lisans YETMİYOR: cihaz filigranı/tarih damgası taşıyan, tanınabilir",
               "insan içeren, tablo ya da tarihî siyah-beyaz kareler vitrine girmez.",
               "Elenenler `REJECTED.txt`te tutulur ve bir daha indirilmez:",
               ""]
    credits += [f"- {needle} — {reason}" for needle, reason in rejected] or ["- (liste boş)"]
    credits.append("")
    total = 0
    for theme, term in THEMES.items():
        try:
            results = search(term, args.per, rejected)
        except Exception as error:                      # ağ/servis hatası
            print(f"  {theme}: atlandı ({error})")
            continue
        for index, item in enumerate(results, start=1):
            name = f"{theme}-{index}.jpg"
            try:
                data = _curl(item["url"], binary=True)
                if len(data) < 10_000:          # hata sayfası / bozuk indirme
                    raise ValueError(f"beklenmedik boyut {len(data)}")
                (OUT / name).write_bytes(data)
            except Exception as error:
                print(f"  {name}: indirilemedi ({error})")
                continue
            total += 1
            credits += [f"## {name}",
                        f"- Kaynak: {item['descriptionurl'] or item['url']}",
                        f"- Lisans: {item['license']}",
                        f"- Yazar: {item['author'] or 'belirtilmemiş'}",
                        ""]
            print(f"  {name}  {item['license']}")

    (OUT / "CREDITS.md").write_text("\n".join(credits))
    print(f"\n{total} görsel → {OUT.relative_to(ROOT)}  (künye: CREDITS.md)")


if __name__ == "__main__":
    main()
