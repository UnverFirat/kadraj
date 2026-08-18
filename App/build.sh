#!/bin/bash
# StoryTemplate'i simulator'da derler, kurar ve başlatır.
#
# Derlemenin TEK kaynağı StoryTemplate.xcodeproj — eskiden burada elle bir
# swiftc çağrısı vardı (Xcode projesi yokken), artık bu script yalnız
# xcodebuild + simctl sarmalayıcısı. Böylece Xcode'da açtığında ve terminalden
# koştuğunda aynı şey derlenir.
#
# Kullanım:
#   ./build.sh                       derle + kur + başlat
#   ./build.sh --no-run              yalnız derle + kur
#   ./build.sh -- --route editor:quote-01 --pro
#                                    "--" sonrası uygulamaya launch bayrağı
set -e
# Yol, cd'DEN ÖNCE mutlaklaştırılır: cd sonrası `dirname "$0"` hâlâ göreli
# olduğu için device.sh yanlış yerde aranıyordu.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

DEVICE="${DEVICE:-iPhone 15 Pro}"
APP_ID="com.fireflysoftware.kadraj"
DERIVED="build/DerivedData"

RUN=1
APP_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-run) RUN=0; shift ;;
    --) shift; APP_ARGS=("$@"); break ;;
    *) echo "bilinmeyen argüman: $1"; exit 2 ;;
  esac
done

# Adı UDID'ye çevir (tek kaynak: Scripts/device.sh — duman testi de aynı
# cihazda koşsun diye ortak). Aynı ada sahip birden fazla simulator olabiliyor;
# o durumda simctl birini kendi seçiyor ve derlediğin uygulama BAKTIĞIN cihaza
# kurulmuyor.
. "$HERE/Scripts/device.sh"
UDID="$(resolve_device "$DEVICE")" || exit 1

echo "== Derleniyor ($DEVICE · $UDID) =="
xcodebuild -project StoryTemplate.xcodeproj \
  -scheme StoryTemplate \
  -destination "id=$UDID" \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  build | tail -3

BUNDLE="$DERIVED/Build/Products/Debug-iphonesimulator/StoryTemplate.app"

echo "== Kuruluyor =="
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl install "$UDID" "$BUNDLE"

if [ "$RUN" = "1" ]; then
  echo "== Başlatılıyor =="
  xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$APP_ID" "${APP_ARGS[@]}"
fi

echo "== Bitti: $BUNDLE =="
