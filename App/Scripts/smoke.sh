#!/bin/bash
# Kritik huninin duman testi: galeri → editör → export → "Videolarım".
#
# NEDEN BÖYLE: XCUITest hedefi yerine launch bayrakları + simctl kullanıyoruz.
# Uygulama zaten `--route`, `--inject-media`, `--open-*` bayraklarıyla her
# ekrana doğrudan açılabiliyor (screenshot otomasyonu için eklendi); aynı yol
# regresyon kontrolü için de yeterli ve Xcode hedefi bakımı gerektirmiyor.
# Test PHPicker gibi sistem arayüzlerine dokunmaz — onlar simctl'den zaten
# sürülemiyor; medya seçimi `--inject-media` ile taklit edilir (assign() ile
# aynı kod yolu).
#
# Kullanım:
#   App/Scripts/smoke.sh                 # derle + koş
#   SKIP_BUILD=1 App/Scripts/smoke.sh    # kurulu uygulamayla koş
#   OUT=/tmp/smoke App/Scripts/smoke.sh  # ekran görüntüleri nereye
set -euo pipefail

cd "$(dirname "$0")/.."
APP_ID="com.storytemplate.app"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
FAILED=0

log()  { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }
fail() { printf "  \033[31mHATA: %s\033[0m\n" "$1"; FAILED=1; }
ok()   { printf "  \033[32mtamam\033[0m — %s\n" "$1"; }

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  log "Derleniyor"
  ./build.sh --no-run >/dev/null
fi

# Çökme tespiti: simulator çökme raporlarını uygulama adına göre sayarız.
# (`simctl spawn booted ps` yok, `launchctl list` de bundle id'yi göstermiyor —
# tek güvenilir sinyal çökme raporu.)
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
crash_count() { ls "$CRASH_DIR" 2>/dev/null | grep -c "^StoryTemplate" || true; }
CRASHES_BEFORE=$(crash_count)

launch() {
  xcrun simctl terminate booted "$APP_ID" >/dev/null 2>&1 || true
  if ! xcrun simctl launch booted "$APP_ID" "$@" >/dev/null 2>&1; then
    fail "başlatılamadı: $*"
    return 1
  fi
  sleep "${WAIT:-6}"
  local now
  now=$(crash_count)
  if [ "$now" != "$CRASHES_BEFORE" ]; then
    fail "çökme raporu üretildi: $*"
    CRASHES_BEFORE="$now"
    return 1
  fi
  return 0
}

shot() { xcrun simctl io booted screenshot "$OUT/$1.png" >/dev/null 2>&1; }

# GERÇEK fotoğrafla koş: `--inject-media` yol verilmezse sentetik gradyan
# enjekte ediyor, yani "kullanıcının gerçek fotosu" yolu duman testinde hiç
# görülmüyordu (kadraj/kırpma hataları sentetik görüntüde fark edilmiyor).
# Fotoğrafı uygulamanın kabına kopyalayıp yolunu veriyoruz (sandbox).
PHOTO=""
SOURCE_PHOTO="tools/samples/source/food-1.jpg"
if [ -f "../$SOURCE_PHOTO" ]; then
  CONTAINER=$(xcrun simctl get_app_container booted "$APP_ID" data 2>/dev/null || true)
  if [ -n "$CONTAINER" ]; then
    cp "../$SOURCE_PHOTO" "$CONTAINER/Documents/smoke-photo.jpg"
    PHOTO="$CONTAINER/Documents/smoke-photo.jpg"
    ok "gerçek test fotoğrafı hazır"
  fi
fi

log "1/5 Galeri açılıyor"
launch && ok "galeri" || true
shot "01-galeri"

log "2/5 Editör (boş proje)"
launch --route editor:reel-collage-01 && ok "editör boş açıldı" || true
shot "02-editor-bos"

log "3/5 Medya seçimi + önizleme"
WAIT=14 launch --route editor:minimal-fade-01 --inject-media $PHOTO && ok "önizleme render edildi" || true
shot "03-onizleme"

log "4/5 Export (Pro, filigransız)"
WAIT=20 launch --route preview:minimal-fade-01 --inject-media $PHOTO --pro && ok "export bitti" || true
shot "04-export"

log "5/5 Videolarım + Ayarlar"
launch --open-videos && ok "videolarım" || true
shot "05-videolarim"
launch --open-settings && ok "ayarlar" || true
shot "06-ayarlar"
launch --open-paywall && ok "paywall" || true
shot "07-paywall"

# İngilizce yol: lokalizasyon kırılırsa (eksik anahtar, çökme) burada görünür.
log "EN dili"
launch -AppleLanguages '(en)' -AppleLocale 'en_US' && ok "İngilizce açıldı" || true
shot "08-en"

echo
if [ "$FAILED" = "0" ]; then
  printf "\033[32mDuman testi geçti.\033[0m Ekran görüntüleri: %s\n" "$OUT"
else
  printf "\033[31mDuman testi BAŞARISIZ.\033[0m Ekran görüntüleri: %s\n" "$OUT"
fi
exit "$FAILED"
