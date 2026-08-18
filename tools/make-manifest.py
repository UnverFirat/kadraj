#!/usr/bin/env python3
"""templates/manifest.json'u şablon dosyalarından üretir.

Manifest CDN'in tek giriş noktasıdır (galeri listesi, rozetler, sürümler).
Şablon içeriği değişince ilgili girdinin `version`'ı ELLE artırılmalı —
uygulama cache anahtarı `id-vN` olduğu için indirmeyi bu tetikler.
Script mevcut manifestteki version/tags/minAppVersion değerlerini KORUR,
yalnız yeni şablonları ekler ve ad/kategori/isPro alanlarını tazeler.

Kullanım:  python3 tools/make-manifest.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates"
MANIFEST = TEMPLATES / "manifest.json"

previous = {}
order = []
previous_doc = {}
if MANIFEST.exists():
    previous_doc = json.loads(MANIFEST.read_text())
    for entry in previous_doc["templates"]:
        previous[entry["id"]] = entry
        order.append(entry["id"])

# Galeri sırası = manifest sırası (sunucudan yönetilir) → mevcut sıra korunur,
# yeni şablonlar sona eklenir.
paths = [p for p in sorted(TEMPLATES.glob("*.json")) if p.name != "manifest.json"]
paths.sort(key=lambda p: (order.index(p.stem) if p.stem in order else len(order), p.stem))

entries = []
for path in paths:
    template = json.loads(path.read_text())
    old = previous.get(template["id"], {})
    entries.append({
        "id": template["id"],
        "version": old.get("version", 1),
        "category": template.get("category", "minimal"),
        "isPro": template.get("isPro", False),
        "tags": old.get("tags", []),
        "minAppVersion": old.get("minAppVersion", "1.0.0"),
        "template": path.name,
        "thumbnail": f"thumbs/{template['id']}.jpg",
        "preview": f"previews/{template['id']}.mp4",
        "name": template["name"],
    })

# YAYIN NUMARASI. Uygulama, diskteki (CDN'den indirilmiş) manifest ile paketle
# gelen manifestin hangisinin yeni olduğuna buna bakarak karar veriyor
# (`TemplateCatalog.current()`): sayı artmazsa güncellenen uygulamanın yeni
# şablonları eski bir indirmenin altında kalıyor. İçerik değişmediyse
# artırılmaz — manifest her koşuda gereksizce kirlenmesin.
revision = previous_doc.get("revision", 0)
if entries != previous_doc.get("templates") or "revision" not in previous_doc:
    revision += 1

MANIFEST.write_text(json.dumps(
    {"manifestVersion": 1, "revision": revision, "templates": entries},
    ensure_ascii=False, indent=2) + "\n")
print(f"{MANIFEST.relative_to(ROOT)} — {len(entries)} şablon · yayın {revision}")
