#!/bin/sh
# Şablonlar TEK kaynaktan gelir: depo kökündeki `templates/` klasörü.
# Bundle'daki bu kopya katalogun "seed"idir (ilk açılış + çevrimdışı liste);
# CDN açıkken TemplateCatalog bunun üstüne yazar. Xcode'a dosya dosya
# eklemek yerine derleme anında kopyalanır — yeni şablon eklemek için
# projeye dokunmak gerekmesin.
set -e

SRC="$SRCROOT/../templates"
DEST="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

if [ ! -d "$SRC" ]; then
  echo "error: şablon klasörü bulunamadı: $SRC"
  exit 1
fi

mkdir -p "$DEST"
# Bundle kökü uygulamanın kendi dosyalarını da barındırır — silme yok, üzerine
# yaz. Eski/kaldırılmış şablonlar için Clean Build Folder yeterli.
cp "$SRC"/*.json "$DEST/"

# Galeri posterlerinin YALNIZ BİR KISMI pakete girer (bkz.
# templates/seed-posters.txt). Şablon JSON'larının tamamı ~1 MB, ama 100+
# şablonun iki dilli posteri 16 MB ve katalog büyüdükçe doğrusal artıyor —
# uygulama indirme boyutunu içerik sayısına bağlamak sürdürülebilir değil.
# Listede olmayan posterler ilk görüntülendiğinde CDN'den inip önbelleğe
# alınır; inene kadar kart `TemplatePreview` ile şablonun kendi
# katmanlarından çizilir, yani hiçbir zaman boş kalmaz.
#
# previews/ (~85 MB) hiç paketlenmez — önizleme videoları yalnız CDN'den.
SEED_LIST="$SRC/seed-posters.txt"
if [ -d "$SRC/thumbs" ] && [ -f "$SEED_LIST" ]; then
  mkdir -p "$DEST/thumbs"
  seeded=0
  # Yorum ve boş satırları at, kalan her satır bir şablon id'si.
  while IFS= read -r id; do
    id="${id%%#*}"
    id="$(echo "$id" | tr -d '[:space:]')"
    [ -n "$id" ] || continue
    if [ -f "$SRC/thumbs/$id.jpg" ]; then
      cp "$SRC/thumbs/$id.jpg" "$DEST/thumbs/"
      seeded=$((seeded + 1))
    else
      echo "warning: seed posteri yok, atlandı: $id.jpg"
    fi
    # Diğer dillerin posterleri (thumbs/en/…): şablon metinleri posterde
    # göründüğü için poster de dile bağlı.
    for lang in "$SRC"/thumbs/*/; do
      [ -d "$lang" ] || continue
      name=$(basename "$lang")
      if [ -f "$lang$id.jpg" ]; then
        mkdir -p "$DEST/thumbs/$name"
        cp "$lang$id.jpg" "$DEST/thumbs/$name/"
      fi
    done
  done < "$SEED_LIST"
  echo "note: $seeded seed posteri paketlendi (gerisi CDN'den)"
fi

# Lottie varlıkları (assets/, ~25 KB) seed'e girer: şablon JSON'u paketten
# geliyorsa gösterdiği animasyon da paketten gelmeli, yoksa katman yer tutucuya
# düşer. CDN'den inen şablonların varlıkları ileride paket (zip) yoluyla gelecek.
if [ -d "$SRC/assets" ]; then
  mkdir -p "$DEST/assets"
  cp "$SRC"/assets/*.json "$DEST/assets/"
fi

echo "note: $(ls -1 "$SRC"/*.json | wc -l | tr -d ' ') şablon dosyası paketlendi"
