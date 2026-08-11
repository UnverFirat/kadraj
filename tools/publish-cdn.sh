#!/bin/bash
# Şablon katalogunu CDN'e yüklenecek bir klasöre hazırlar.
#
# NE YAPAR: `templates/` içindeki yayınlanabilir dosyaları (manifest, şablon
# JSON'ları, posterler, önizlemeler, lottie varlıkları) `dist/cdn/` altına
# kopyalar, tutarlılığı doğrular ve yükleme komutlarını yazdırır. Depoyu
# olduğu gibi yüklemek yerine ayrı bir klasör üretmesinin sebebi: `templates/`
# içinde yayına GİTMEMESİ gereken dosyalar var (seed-posters.txt, üretim
# kaynakları) ve yanlışlıkla yüklenen bir dosya CDN'de kalıcı olur.
#
#   tools/publish-cdn.sh                 # dist/cdn hazırla + doğrula
#   tools/publish-cdn.sh --with-previews # önizleme mp4'lerini de al (~85 MB)
#   OUT=/tmp/cdn tools/publish-cdn.sh
#
# Yükleme (örnek, herhangi bir statik barındırma olur):
#   aws s3 sync dist/cdn s3://<bucket>/v1/ --delete \
#       --cache-control "public, max-age=300"
#   # posterler ve şablonlar içerik-adresli (id-vN) → uzun cache güvenli:
#   aws s3 cp dist/cdn/thumbs s3://<bucket>/v1/thumbs --recursive \
#       --cache-control "public, max-age=31536000, immutable"
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="templates"
OUT="${OUT:-dist/cdn}"
WITH_PREVIEWS=0
[ "${1:-}" = "--with-previews" ] && WITH_PREVIEWS=1

command -v python3 >/dev/null || { echo "hata: python3 gerekli"; exit 1; }

echo "== Doğrulanıyor =="
python3 tools/build-templates.py --lint-only

# Manifest ile dosyalar birebir örtüşmeli; eksik bir şablon CDN'de kırık
# link demek ve uygulama o kartı hiç gösteremez.
python3 - <<'PY'
import json, pathlib, sys
root = pathlib.Path("templates")
manifest = json.loads((root / "manifest.json").read_text())
problems = []
for entry in manifest["templates"]:
    for key in ("template", "thumbnail"):
        path = root / entry[key]
        if not path.exists():
            problems.append(f"{entry['id']}: {entry[key]} yok")
files = {p.stem for p in root.glob("*.json")} - {"manifest"}
ids = {e["id"] for e in manifest["templates"]}
for extra in sorted(files - ids):
    problems.append(f"{extra}.json manifestte yok (yüklenmeyecek)")
for missing in sorted(ids - files):
    problems.append(f"{missing} manifestte var ama dosyası yok")
if problems:
    print("MANİFEST TUTARSIZ:")
    for p in problems:
        print("  ✗", p)
    sys.exit(1)
print(f"  manifest tutarlı — {len(ids)} şablon")
PY

echo "== dist hazırlanıyor → $OUT =="
rm -rf "$OUT"
mkdir -p "$OUT/thumbs" "$OUT/assets"

cp "$SRC/manifest.json" "$OUT/"
cp "$SRC"/*.json "$OUT/" 2>/dev/null || true
# seed-posters.txt yayına gitmez (yalnız uygulama paketini ilgilendirir).
rm -f "$OUT/seed-posters.txt"

cp "$SRC"/thumbs/*.jpg "$OUT/thumbs/"
for lang in "$SRC"/thumbs/*/; do
  [ -d "$lang" ] || continue
  name=$(basename "$lang")
  mkdir -p "$OUT/thumbs/$name"
  cp "$lang"*.jpg "$OUT/thumbs/$name/"
done

[ -d "$SRC/assets" ] && cp "$SRC"/assets/*.json "$OUT/assets/" 2>/dev/null || true

if [ "$WITH_PREVIEWS" = "1" ] && [ -d "$SRC/previews" ]; then
  mkdir -p "$OUT/previews"
  cp "$SRC"/previews/*.mp4 "$OUT/previews/"
fi

echo
echo "== Hazır =="
du -sh "$OUT"
find "$OUT" -type f | wc -l | tr -d ' ' | sed 's/^/  dosya: /'
echo
echo "Yükledikten sonra App/Info.plist içindeki TemplateCDNBaseURL'i"
echo "kökün URL'iyle doldur (ör. https://cdn.ornek.com/v1) ve şunu doğrula:"
echo "  curl -sI <url>/manifest.json | head -1     → 200 beklenir"
echo "  cd App && ./build.sh -- --cdn <url>"
