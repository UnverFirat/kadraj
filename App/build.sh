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
cd "$(dirname "$0")"

DEVICE="${DEVICE:-iPhone 15 Pro}"
APP_ID="com.storytemplate.app"
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

# Adı UDID'ye çevir. Aynı ada sahip birden fazla simulator olabiliyor (Xcode
# sürüm yükseltmeleri eskiyi bırakıyor) — o durumda simctl birini kendi seçiyor
# ve derlediğin uygulama BAKTIĞIN cihaza kurulmuyor. Belirsizse durup soruyoruz.
if [[ "$DEVICE" =~ ^[0-9A-F]{8}- ]]; then
  UDID="$DEVICE"
else
  ALL="$(xcrun simctl list devices available \
         | sed -n "s/^ *$DEVICE (\([0-9A-F-]*\)).*/\1/p")"
  # Ad birden fazlaysa AÇIK olanı seç — kullanıcı baktığı simulator'ı kasteder.
  BOOTED="$(xcrun simctl list devices available \
            | sed -n "s/^ *$DEVICE (\([0-9A-F-]*\)) (Booted).*/\1/p")"
  MATCHES="$ALL"
  [ -n "$BOOTED" ] && MATCHES="$BOOTED"
  COUNT="$(echo "$MATCHES" | grep -c . || true)"
  if [ "$COUNT" = "0" ]; then
    echo "hata: '$DEVICE' adında kullanılabilir simulator yok"; exit 1
  elif [ "$COUNT" != "1" ]; then
    echo "hata: '$DEVICE' adında $COUNT (açık) simulator var — DEVICE=<udid> ile seç:"
    echo "$MATCHES" | sed 's/^/  /'
    exit 1
  fi
  UDID="$MATCHES"
fi

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
