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

# GALERİ POSTERLERİNİN TAMAMI pakete girer.
#
# Eskiden yalnız bir liste (`seed-posters.txt`, ~28 şablon) paketlenirdi,
# gerisi CDN'den inecekti. Ama CDN yapılandırılmamış bir yayında o "gerisi"
# HİÇ gelmiyor: mağazadan gelen kullanıcı 127 kartın ~99'unu yer tutucu olarak
# görüyordu — üstelik galeri vitrini bu uygulamanın satış argümanının kendisi.
#
# Boyut ÖLÇÜLDÜ ve karar ona göre verildi: poster uygulamada en fazla 512 px'de
# gösterildiği için 540 px / JPEG 0.6 yeterli (bkz. TemplateKitAssets), bu da
# 127 şablon × 2 dil = 254 poster için ~12 MB demek (0.85 kalitede 20 MB'dı).
# 12 MB'lık bir indirme karşılığında galeri CDN olmadan da eksiksiz görünüyor.
#
# previews/ (~85 MB) hiç paketlenmez — önizleme videoları yalnız CDN'den.
if [ -d "$SRC/thumbs" ]; then
  mkdir -p "$DEST/thumbs"
  cp "$SRC"/thumbs/*.jpg "$DEST/thumbs/"
  # Diğer dillerin posterleri (thumbs/en/…): şablon metinleri posterde
  # göründüğü için poster de dile bağlı.
  for lang in "$SRC"/thumbs/*/; do
    [ -d "$lang" ] || continue
    name=$(basename "$lang")
    mkdir -p "$DEST/thumbs/$name"
    cp "$lang"*.jpg "$DEST/thumbs/$name/"
  done
  KB=$(du -sk "$DEST/thumbs" | cut -f1)
  echo "note: $(find "$DEST/thumbs" -name '*.jpg' | wc -l | tr -d ' ') poster paketlendi ($((KB / 1024)) MB)"
  # Katalog büyüdükçe bu doğrusal artıyor. Eşiği aşarsa karar yeniden
  # verilmeli (kaliteyi düşür, dili azalt ya da CDN'i zorunlu kıl) — sessizce
  # 40 MB'lık bir uygulamaya doğru kaymasın.
  if [ "$KB" -gt 20480 ]; then
    echo "warning: paketteki posterler $((KB / 1024)) MB — 20 MB eşiği aşıldı, seed stratejisi gözden geçirilmeli"
  fi
fi

# Lottie varlıkları (assets/, ~25 KB) seed'e girer: şablon JSON'u paketten
# geliyorsa gösterdiği animasyon da paketten gelmeli, yoksa katman yer tutucuya
# düşer. CDN'den inen şablonların varlıkları ileride paket (zip) yoluyla gelecek.
if [ -d "$SRC/assets" ]; then
  mkdir -p "$DEST/assets"
  cp "$SRC"/assets/*.json "$DEST/assets/"
fi

echo "note: $(ls -1 "$SRC"/*.json | wc -l | tr -d ' ') şablon dosyası paketlendi"
