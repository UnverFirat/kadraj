#!/bin/bash
# Simulator seçiminin TEK kaynağı: ad (ya da UDID) -> UDID.
#
# NEDEN AYRI DOSYA: `build.sh` derlediği cihazı adından çözerken `smoke.sh`
# `booted` kullanıyordu. Birden fazla simulator açıkken bunlar FARKLI cihazlar
# olabiliyor — duman testi eski bir kurulumu test edip "geçti" diyordu, yani
# yanlış güven veren bir yeşil. Artık ikisi de burayı çağırır ve aynı UDID'de
# çalışır.
#
# Kullanım:
#   . "$(dirname "$0")/device.sh"     # smoke.sh: Scripts/ içinden
#   UDID="$(resolve_device "${DEVICE:-iPhone 15 Pro}")" || exit 1

# Adı UDID'ye çevirir. Aynı ada sahip birden fazla simulator olabiliyor (Xcode
# sürüm yükseltmeleri eskiyi bırakıyor); belirsizse durup sorar.
resolve_device() {
  local wanted="$1"
  if [[ "$wanted" =~ ^[0-9A-Fa-f]{8}- ]]; then
    echo "$wanted"
    return 0
  fi
  local all booted matches count
  all="$(xcrun simctl list devices available \
         | sed -n "s/^ *$wanted (\([0-9A-F-]*\)).*/\1/p")"
  # Ad birden fazlaysa AÇIK olanı seç — kullanıcı baktığı simulator'ı kasteder.
  booted="$(xcrun simctl list devices available \
            | sed -n "s/^ *$wanted (\([0-9A-F-]*\)) (Booted).*/\1/p")"
  matches="$all"
  [ -n "$booted" ] && matches="$booted"
  count="$(echo "$matches" | grep -c . || true)"
  if [ "$count" = "0" ]; then
    echo "hata: '$wanted' adında kullanılabilir simulator yok" >&2
    return 1
  elif [ "$count" != "1" ]; then
    {
      echo "hata: '$wanted' adında $count (açık) simulator var — DEVICE=<udid> ile seç:"
      echo "$matches" | sed 's/^/  /'
    } >&2
    return 1
  fi
  echo "$matches"
}
