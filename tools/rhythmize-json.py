#!/usr/bin/env python3
"""Ritim dönüşümünü doğrudan `templates/*.json` dosyalarına uygular.

NEDEN AYRI ARAÇ: katalogun bir kısmı `tools/templates_src/` batch dosyalarından
ÜRETİLİYOR (orada dönüşüm `build-templates.py` içinde otomatik), ama MVP'nin ilk
şablonları elle yazılmış JSON'lar — üretim hattı onlara hiç dokunmuyor. Bu araç
o dosyalara aynı dönüşümü (`templatelib.rhythmize`) uygular.

Dönüşüm İDEMPOTENT: zaten çok sahneli bir şablona ikinci kez uygulanmaz
(`rhythmize` None döner). Lint'ten geçmeyen dönüşüm YAZILMAZ — tasarımı bozan
otomatik bir değişikliği katalogda bırakmak, ritimden büyük zarar.

    python3 tools/rhythmize-json.py --list         # uygun dosyaları göster
    python3 tools/rhythmize-json.py quote-01 …     # verilenleri çevir
    python3 tools/rhythmize-json.py --all          # uygun olan hepsini çevir
    python3 tools/rhythmize-json.py --all --dry-run

Sonrasında `python3 tools/make-manifest.py` (içerik değiştiği için ilgili
girdilerin `version`'ı ELLE artırılmalı — cache anahtarı `id-vN`).
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates"
SRC = ROOT / "tools" / "templates_src"

sys.path.insert(0, str(ROOT / "tools"))
from templatelib import lint, dumps, rhythmize, cut_density  # noqa: E402


def produced_by_batches():
    """Batch dosyalarının yazdığı şablon id'leri (bu araç onlara dokunmaz)."""
    import importlib.util
    ids = set()
    for path in sorted(SRC.glob("*.py")):
        if path.name.startswith("_"):
            continue
        spec = importlib.util.spec_from_file_location(f"batch_{path.stem}", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for make in getattr(module, "TEMPLATES", []):
            ids.add(make().id)
    return ids


def candidates():
    """Dönüşüme uygun, üretim hattı DIŞINDAKİ dosyalar."""
    produced = produced_by_batches()
    result = []
    for path in sorted(TEMPLATES.glob("*.json")):
        if path.name == "manifest.json":
            continue
        doc = json.loads(path.read_text())
        if doc["id"] in produced:
            continue
        if rhythmize(doc) is None:
            continue
        result.append(doc["id"])
    return result


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    ids = [a for a in args if not a.startswith("--")]

    if "--list" in args:
        found = candidates()
        print(f"{len(found)} uygun dosya (üretim hattı dışında):")
        for tid in found:
            print(f"  {tid}")
        return

    if "--all" in args:
        ids = candidates()
    if not ids:
        print(__doc__)
        sys.exit(2)

    changed, skipped = [], []
    for tid in ids:
        path = TEMPLATES / f"{tid}.json"
        if not path.exists():
            print(f"  ! yok: {tid}")
            skipped.append(tid)
            continue
        doc = json.loads(path.read_text())
        result = rhythmize(doc)
        if result is None:
            print(f"  - uygun değil (zaten çok sahneli / medyası küçük): {tid}")
            skipped.append(tid)
            continue
        problems = lint(result)
        if problems:
            print(f"  ! lint reddetti, dosya KORUNDU ({tid}): {problems[0]}")
            skipped.append(tid)
            continue
        before = cut_density(doc)[2]
        after = cut_density(result)[2]
        if not dry_run:
            path.write_text(dumps(result))
        print(f"  ✓ {tid}: {len(result['scenes'])} sahne, "
              f"kesme yoğunluğu {before:.2f} → {after:.2f}"
              + (" (dry-run)" if dry_run else ""))
        changed.append(tid)

    print(f"\n{len(changed)} dosya çevrildi, {len(skipped)} atlandı")
    if changed and not dry_run:
        print("Şimdi: python3 tools/make-manifest.py  (ve değişen girdilerin "
              "`version`'ını artır)")


if __name__ == "__main__":
    main()
