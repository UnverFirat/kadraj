#!/usr/bin/env python3
"""Şablon posterlerinden kontak baskısı (grid) üretir.

NEDEN: 100 şablonu tek tek açıp bakmak mümkün değil; ama katalogda gözle
görülmesi gereken şeyler var (metin fotoğrafın üstünde kayboluyor mu, kadraj
dengeli mi, iki şablon birbirinin aynısı mı görünüyor). Kontak baskısı bütün
katalogu birkaç görselde toplar — yanlış olan bakışta belli olur.

    python3 tools/contact-sheet.py                     # tüm katalog
    python3 tools/contact-sheet.py --filter ref-       # id öneki süz
    python3 tools/contact-sheet.py --cols 6 --out /tmp/sheet
"""

import argparse
import json
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "templates"

CELL_W, CELL_H = 220, 391          # 9:16
LABEL_H = 34
PAD = 10
BG = (16, 16, 18)
FG = (235, 235, 240)
DIM = (140, 140, 150)


def load_font(size, bold=False):
    for name in (["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                  "/System/Library/Fonts/Helvetica.ttc"] if bold else
                 ["/System/Library/Fonts/Supplemental/Arial.ttf",
                  "/System/Library/Fonts/Helvetica.ttc"]):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--filter", default="")
    ap.add_argument("--cols", type=int, default=7)
    ap.add_argument("--rows", type=int, default=5, help="sayfa başına satır")
    ap.add_argument("--out", default=str(ROOT / "tools" / "contact"))
    args = ap.parse_args()

    manifest = json.loads((TEMPLATES / "manifest.json").read_text())
    entries = [e for e in manifest["templates"] if e["id"].startswith(args.filter)]
    if not entries:
        print("eşleşen şablon yok")
        return

    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    per_page = args.cols * args.rows
    title_font = load_font(15, bold=True)
    meta_font = load_font(13)
    head_font = load_font(20, bold=True)

    pages = [entries[i:i + per_page] for i in range(0, len(entries), per_page)]
    written = []
    for page_index, page in enumerate(pages, start=1):
        rows = (len(page) + args.cols - 1) // args.cols
        width = args.cols * (CELL_W + PAD) + PAD
        height = rows * (CELL_H + LABEL_H + PAD) + PAD + 44
        sheet = Image.new("RGB", (width, height), BG)
        draw = ImageDraw.Draw(sheet)
        draw.text((PAD, 12),
                  f"Şablon kataloğu — sayfa {page_index}/{len(pages)} "
                  f"({len(entries)} şablon)", font=head_font, fill=FG)

        for index, entry in enumerate(page):
            col, row = index % args.cols, index // args.cols
            x = PAD + col * (CELL_W + PAD)
            y = 44 + PAD + row * (CELL_H + LABEL_H + PAD)
            poster = TEMPLATES / entry["thumbnail"]
            if poster.exists():
                image = Image.open(poster).convert("RGB")
                image = image.resize((CELL_W, CELL_H), Image.LANCZOS)
                sheet.paste(image, (x, y))
            else:
                draw.rectangle([x, y, x + CELL_W, y + CELL_H], fill=(40, 40, 46))
                draw.text((x + 8, y + CELL_H // 2), "poster yok",
                          font=meta_font, fill=DIM)

            name = entry["name"].get("tr", entry["id"])
            if entry.get("isPro"):
                name += "  ·PRO"
            draw.text((x + 2, y + CELL_H + 4), name[:30], font=title_font, fill=FG)
            draw.text((x + 2, y + CELL_H + 20),
                      f"{entry['category']} · {entry['id']}"[:34],
                      font=meta_font, fill=DIM)

        path = out_dir / f"sheet-{page_index}.png"
        sheet.save(path, quality=92)
        written.append(path)
        print(f"  {path}  ({len(page)} şablon)")

    print(f"{len(written)} sayfa yazıldı")


if __name__ == "__main__":
    main()
