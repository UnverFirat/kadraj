#!/usr/bin/env python3
"""`tools/templates_src/*.py` batch dosyalarını çalıştırıp `templates/` altına
şablon JSON'u yazar ve her birini lint'ten geçirir.

Her batch dosyası `TEMPLATES` adında bir liste dışa açar; listedeki her eleman
argümansız çağrılınca bir `Template` döndüren fonksiyondur.

    python3 tools/build-templates.py              # hepsini üret
    python3 tools/build-templates.py promo        # yalnız promo batch'i
    python3 tools/build-templates.py --check      # yaz, sonra hepsini lint et
    python3 tools/build-templates.py --lint-only  # dosyalara dokunma, yalnız denetle

`--lint-only` klasördeki TÜM şablonları (elle yazılmış eskiler dahil) denetler;
üretim hattına girmeyen bir şablon da bozuksa burada görünür.
"""

import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "templates_src"
OUT = ROOT / "templates"

sys.path.insert(0, str(ROOT / "tools"))
from templatelib import (lint, dumps, enliven, rhythmize, cut_density,  # noqa: E402
                         needs_rhythm, rhythm_debt, RHYTHM_BATCH,
                         RHYTHM_MIN_DENSITY, RHYTHM_DEBT_BUDGET)


def load_batches(only=None):
    batches = []
    for path in sorted(SRC.glob("*.py")):
        if path.name.startswith("_"):
            continue
        if only and path.stem not in only:
            continue
        spec = importlib.util.spec_from_file_location(f"batch_{path.stem}", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        batches.append((path.stem, getattr(module, "TEMPLATES", [])))
    return batches


def check_rhythm(docs):
    """Kesme yoğunluğu borcunu raporlar; borç ARTMIŞSA hata döner.

    Neden şablon şablon hata değil: mevcut katalogun büyük kısmı eşiğin altında
    (bilinen borç, `YAPILACAKLAR.md` 1.2 — batch batch eritilecek). Ama YENİ
    eklenen durağan bir şablon borcu artırır ve burada düşer. Borç eridikçe
    `templatelib.RHYTHM_DEBT_BUDGET` de düşürülmeli.
    """
    media = [d for d in docs if needs_rhythm(d)]
    if not media:
        return []
    below = rhythm_debt(docs)
    average = sum(cut_density(d)[2] for d in media) / len(media)
    print(f"\nRitim: {len(media) - len(below)}/{len(media)} medyalı şablon "
          f"≥{RHYTHM_MIN_DENSITY} kesme/sn · ortalama {average:.2f} "
          f"· borç {len(below)}/{RHYTHM_DEBT_BUDGET}")
    if len(below) > RHYTHM_DEBT_BUDGET:
        worst = ", ".join(f"{tid} ({density:.2f})" for tid, density in below[:8])
        return [f"kesme yoğunluğu borcu arttı: {len(below)} > "
                f"{RHYTHM_DEBT_BUDGET}. Yeni şablonlar en az "
                f"{RHYTHM_MIN_DENSITY} kesme/sn taşımalı (~2,5 sn'de bir sahne). "
                f"En durağanlar: {worst}"]
    if len(below) < RHYTHM_DEBT_BUDGET:
        print(f"  not: borç {RHYTHM_DEBT_BUDGET} → {len(below)} düştü, "
              f"templatelib.RHYTHM_DEBT_BUDGET güncellenebilir")
    return []


def main():
    args = [a for a in sys.argv[1:]]
    lint_only = "--lint-only" in args
    check = "--check" in args or lint_only
    only = [a for a in args if not a.startswith("--")] or None

    written = []
    failures = []
    rhythm_applied = []
    rhythm_skipped = []

    if not lint_only:
        for name, makers in load_batches(only):
            for make in makers:
                template = make()
                doc = template.build()
                # RİTİM: listedeki şablonlar tek sahneliden çok sahneliye
                # çevrilir (bkz. templatelib.rhythmize). Dönüşüm lint'ten
                # geçmezse ŞABLON KORUNUR — tasarımı bozan bir otomatik
                # dönüşümü katalogda bırakmak, ritimden daha büyük bir zarar.
                if doc["id"] in RHYTHM_BATCH:
                    rhythmic = rhythmize(doc)
                    if rhythmic is not None:
                        problems = lint(rhythmic)
                        if problems:
                            print(f"  ! ritim atlandı ({doc['id']}): {problems[0]}")
                            rhythm_skipped.append(doc["id"])
                        else:
                            doc = rhythmic
                            rhythm_applied.append(doc["id"])
                doc = enliven(doc)
                errors = lint(doc)
                if errors:
                    failures.extend(errors)
                    continue
                path = OUT / f"{doc['id']}.json"
                path.write_text(dumps(doc))
                written.append(doc["id"])
            print(f"  {name}: {len(makers)} şablon")

    if check:
        docs = []
        for path in sorted(OUT.glob("*.json")):
            if path.name == "manifest.json":
                continue
            doc = json.loads(path.read_text())
            docs.append(doc)
            failures.extend(lint(doc))
        failures.extend(check_rhythm(docs))

    if written:
        print(f"\n{len(written)} şablon yazıldı → templates/")
    if rhythm_applied or rhythm_skipped:
        print(f"Ritim dönüşümü: {len(rhythm_applied)} uygulandı, "
              f"{len(rhythm_skipped)} atlandı")
    if failures:
        print(f"\n{len(failures)} LINT HATASI:")
        for f in failures:
            print(f"  ✗ {f}")
        sys.exit(1)
    print("Lint temiz.")


if __name__ == "__main__":
    main()
