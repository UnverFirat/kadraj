#!/bin/bash
# Kadraj'ı GERÇEK iPhone'a derler, kurar ve başlatır.
#
# NEDEN AYRI SCRIPT: `build.sh` simulator içindir (`simctl`). Cihaz tarafı
# bambaşka bir hat: imzalama gerekiyor, kurulum `devicectl` ile yapılıyor ve
# ürün `Debug-iphoneos` altına çıkıyor. İkisini tek script'e sıkıştırmak
# ikisini de okunmaz yapıyordu.
#
# Cihaz doğrulaması YAPILACAKLAR §4.1'deki P0 iş: katalogun %62'si (montaj
# şablonları) simulator'da doğrulanamıyor, çünkü simulator'da montaj export'unun
# 2. geçişi çöküyor (IOSurface havuzu) ve çıktı metinsiz kalıyor. Cihazda tam
# export yolu çalışır — bu yüzden bu script sık kullanılacak.
#
# Kullanım:
#   ./install-device.sh                    derle + kur + başlat
#   ./install-device.sh --no-run           yalnız derle + kur
#   ./install-device.sh --release          Release derle (AKICILIĞI BUNDA ÖLÇ)
#   ./install-device.sh --list             bağlı cihazları göster
#   DEVICE_ID=<udid> ./install-device.sh   belirli bir cihaza kur
#
# HANGİ CONFIGURATION: varsayılan Debug, çünkü günlük iş hata ayıklamak.
# Ama SwiftUI'da Debug ile Release arasındaki fark hissedilir: Debug `-Onone`
# derlenir, görünüm gövdeleri ve generic'ler optimize edilmez, dokunuş→çizim
# yolu belirgin biçimde yavaşlar. "Arayüz kasıyor mu" sorusunun cevabı
# Debug build'de ARANMAZ — önce `--release` ile kur, sonra karar ver.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

APP_ID="com.fireflysoftware.kadraj"
DERIVED="build/DerivedDataDevice"
RUN=1
CONFIG="Debug"

while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      xcrun devicectl list devices
      exit 0 ;;
    --no-run) RUN=0; shift ;;
    --release) CONFIG="Release"; shift ;;
    *) echo "bilinmeyen argüman: $1"; exit 2 ;;
  esac
done

# Cihaz seçimi: DEVICE_ID verilmemişse bağlı TEK iPhone'u kullan. Birden fazla
# varsa durup sorar — yanlış telefona kurup "düzelmemiş" demek en can sıkıcı
# yanlış negatif (simulator tarafında aynı hata bir kez yaşandı).
if [ -z "${DEVICE_ID:-}" ]; then
  # UDID'yi SÜTUN SAYARAK bulma: hem cihaz adı ("Ali Fırat iPhone'u") hem model
  # ("iPhone 14 Pro (iPhone15,2)") boşluk içeriyor, sütun indeksi kayıyor.
  # Ayrıca "unavailable" içinde "available" geçtiği için durum eşleşmesi
  # baştaki boşlukla yapılır — yoksa kapalı Apple Watch de eşleşiyor.
  MATCHES="$(xcrun devicectl list devices 2>/dev/null \
             | grep -E '\(iPhone[0-9]+,[0-9]+\)' | grep -v 'unavailable' \
             | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')"
  COUNT="$(printf "%s\n" "$MATCHES" | grep -c . || true)"
  if [ "$COUNT" -eq 0 ]; then
    echo "Bağlı iPhone yok. Telefonu kabloyla bağla, kilidini aç ve"
    echo "'Bu bilgisayara güven' de. Ayrıca Ayarlar > Gizlilik ve Güvenlik >"
    echo "Geliştirici Modu açık olmalı."
    exit 1
  elif [ "$COUNT" -gt 1 ]; then
    echo "Birden fazla iPhone bağlı; DEVICE_ID ver:"
    xcrun devicectl list devices
    exit 1
  fi
  DEVICE_ID="$(printf "%s\n" "$MATCHES" | head -1)"
fi

echo "== Derleniyor ($CONFIG · $DEVICE_ID) =="
# -allowProvisioningUpdates: App ID / profil eksikse Xcode'un kendisi oluşturur.
# DEVELOPMENT_TEAM projede yazılı (N6SRRJ6HCK), burada tekrar edilmiyor.
xcodebuild -project StoryTemplate.xcodeproj \
  -scheme StoryTemplate \
  -destination "id=$DEVICE_ID" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build | tail -3

BUNDLE="$DERIVED/Build/Products/$CONFIG-iphoneos/StoryTemplate.app"

echo "== Kuruluyor =="
xcrun devicectl device install app --device "$DEVICE_ID" "$BUNDLE" | tail -3

if [ "$RUN" = "1" ]; then
  echo "== Başlatılıyor =="
  xcrun devicectl device process launch --device "$DEVICE_ID" "$APP_ID" | tail -1
fi

echo "== Bitti: $BUNDLE =="
