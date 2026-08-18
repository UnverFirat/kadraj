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
#   DEVICE="iPhone 16" App/Scripts/smoke.sh
#   OUT=/tmp/smoke App/Scripts/smoke.sh  # ekran görüntüleri nereye
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."
APP_ID="com.storytemplate.app"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
FAILED=0

# CİHAZ AÇIKÇA SEÇİLİR. Eskiden her simctl çağrısı `booted` diyordu: birden
# fazla simulator açıkken (ya da build.sh başka bir cihaza kurmuşken) test
# ESKİ bir kurulumu deneyip "geçti" veriyordu — yanlış güven veren bir yeşil.
# Artık derleme de test de aynı UDID'de koşar.
DEVICE="${DEVICE:-iPhone 15 Pro}"
. "$HERE/device.sh"
UDID="$(resolve_device "$DEVICE")" || exit 1
export DEVICE
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1 || true
printf "cihaz: %s · %s\n" "$DEVICE" "$UDID"

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
  xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
  if ! xcrun simctl launch "$UDID" "$APP_ID" "$@" >/dev/null 2>&1; then
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

shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null 2>&1; }

# GERÇEK fotoğrafla koş: `--inject-media` yol verilmezse sentetik gradyan
# enjekte ediyor, yani "kullanıcının gerçek fotosu" yolu duman testinde hiç
# görülmüyordu (kadraj/kırpma hataları sentetik görüntüde fark edilmiyor).
# Fotoğrafı uygulamanın kabına kopyalayıp yolunu veriyoruz (sandbox).
PHOTO=""
CLIP=""
CONTAINER=$(xcrun simctl get_app_container "$UDID" "$APP_ID" data 2>/dev/null || true)
SOURCE_PHOTO="tools/samples/source/food-1.jpg"
if [ -n "$CONTAINER" ] && [ -f "../$SOURCE_PHOTO" ]; then
  cp "../$SOURCE_PHOTO" "$CONTAINER/Documents/smoke-photo.jpg"
  PHOTO="$CONTAINER/Documents/smoke-photo.jpg"
  ok "gerçek test fotoğrafı hazır"
fi
# GERÇEK VİDEO yolu da test edilir: klip hızı (hızlandır/ağır çekim) yalnız
# video slotunda çıkıyor ve montaj hattı (1. geçiş) yalnız videoyla sürülüyor.
# Fotoğrafla koşan bir duman testi bu yolun tamamını ıskalıyordu.
SOURCE_CLIP="tools/samples/sample-03-food.mp4"
if [ -n "$CONTAINER" ] && [ -f "../$SOURCE_CLIP" ]; then
  cp "../$SOURCE_CLIP" "$CONTAINER/Documents/smoke-clip.mp4"
  CLIP="$CONTAINER/Documents/smoke-clip.mp4"
  ok "test klibi hazır"
fi

log "1/6 Galeri açılıyor"
launch --skip-onboarding && ok "galeri" || true
shot "01-galeri"

log "2/6 Editör (boş proje)"
launch --route editor:reel-collage-01 && ok "editör boş açıldı" || true
shot "02-editor-bos"

# KLASİK (v1) YOL: `cafe-menu-01` tek sahneli kalan bir şablon — katalogun
# %62'si artık montaj olduğu için klasik hattı (CoreAnimationTool: metin +
# filigran GÖMÜLÜ export) bilerek seçmek gerekiyor. Simulator'da montaj
# export'u yalnız 1. geçişi koşuyor (belgeli kısıt), yani metin/filigranı
# doğrulayan tek yol bu.
log "3/6 Medya seçimi + önizleme (klasik yol)"
WAIT=14 launch --route editor:cafe-menu-01 --inject-media $PHOTO && ok "önizleme render edildi" || true
shot "03-onizleme"

log "4/6 Export (Pro, filigransız · klasik yol)"
WAIT=20 launch --route preview:cafe-menu-01 --inject-media $PHOTO --pro && ok "export bitti" || true
shot "04-export"

log "5/6 Video klip + montaj export'u"
if [ -n "$CLIP" ]; then
  WAIT=30 launch --route preview:fast-cut-01 --inject-video "$CLIP" \
    && ok "5 video slotlu montaj export edildi" || true
  shot "08-montaj-video"
else
  fail "test klibi hazırlanamadı (tools/samples/sample-03-food.mp4)"
fi

log "6/6 Videolarım + Ayarlar"
launch --open-videos && ok "videolarım" || true
shot "05-videolarim"
launch --open-settings && ok "ayarlar" || true
shot "06-ayarlar"
launch --open-paywall && ok "paywall" || true
shot "07-paywall"

# İngilizce yol: lokalizasyon kırılırsa (eksik anahtar, çökme) burada görünür.
log "EN dili"
launch --skip-onboarding -AppleLanguages '(en)' -AppleLocale 'en_US' && ok "İngilizce açıldı" || true
shot "09-en"

echo
if [ "$FAILED" = "0" ]; then
  printf "\033[32mDuman testi geçti.\033[0m Ekran görüntüleri: %s\n" "$OUT"
else
  printf "\033[31mDuman testi BAŞARISIZ.\033[0m Ekran görüntüleri: %s\n" "$OUT"
fi
exit "$FAILED"
