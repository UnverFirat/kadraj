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
from templatelib import lint, dumps, enliven  # noqa: E402


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


def main():
    args = [a for a in sys.argv[1:]]
    lint_only = "--lint-only" in args
    check = "--check" in args or lint_only
    only = [a for a in args if not a.startswith("--")] or None

    written = []
    failures = []

    if not lint_only:
        for name, makers in load_batches(only):
            for make in makers:
                template = make()
                doc = enliven(template.build())
                errors = lint(doc)
                if errors:
                    failures.extend(errors)
                    continue
                path = OUT / f"{doc['id']}.json"
                path.write_text(dumps(doc))
                written.append(doc["id"])
            print(f"  {name}: {len(makers)} şablon")

    if check:
        for path in sorted(OUT.glob("*.json")):
            if path.name == "manifest.json":
                continue
            doc = json.loads(path.read_text())
            failures.extend(lint(doc))

    if written:
        print(f"\n{len(written)} şablon yazıldı → templates/")
    if failures:
        print(f"\n{len(failures)} LINT HATASI:")
        for f in failures:
            print(f"  ✗ {f}")
        sys.exit(1)
    print("Lint temiz.")


if __name__ == "__main__":
    main()
