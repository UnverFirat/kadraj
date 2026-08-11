# Şablon JSON Formatı — v2

Bu doküman şablon dosyasının sözleşmesidir. Uygulama (render motoru), şablon üretim
aracı ve CDN manifesti bu formata göre çalışır. Format platformdan bağımsızdır —
Android'e geçersek şablonlar aynen taşınır, sadece motor yeniden yazılır.

## Tasarım ilkeleri

1. **Preset animasyon, keyframe değil.** MVP'de animasyonlar isimli preset'lerdir
   (`fadeIn`, `slideIn`, `kenBurns`...). Keyframe sistemi hem şablon üretimini hem
   motoru 10 kat zorlaştırır; preset'ler deterministiktir ve export/önizleme
   birebir aynı çıkar. Format ileride `"keyframes"` alanına izin verecek şekilde
   genişleyebilir (bkz. İleri uyumluluk).
2. **Renkler rol üzerinden.** Katmanlar ham hex değil, paletteki bir rolü
   (`"colorRole": "accent"`) referanslar. "Tek dokunuşla renk şeması değiştirme"
   özelliği = paleti değiştirmek. Başka hiçbir şeye dokunulmaz.
3. **Koordinatlar normalize (0–1).** Konum/boyut, kanvasın oranı olarak yazılır.
   1080×1920 sabittir ama önizleme küçük boyutta render edilir; normalize koordinat
   iki dünyayı tek koddan çizer. (Not: farklı en-boy oranına — ör. 1:1 post —
   geçersek şablonlar oran başına ayrı tasarlanır; normalize koordinat oranlar
   arası otomatik uyum vaat etmez.)
4. **İleri uyumluluk.** Eski uygulama yeni şablonu bozmadan reddedebilmeli:
   `schemaVersion` + manifest'teki `minAppVersion` bunu sağlar. Motor, tanımadığı
   preset/alan gördüğünde çökmez, o animasyonu atlar (graceful degrade).

## Üst düzey yapı

```json
{
  "schemaVersion": 1,
  "id": "minimal-fade-01",
  "name": { "en": "Minimal Fade", "tr": "Minimal Geçiş" },
  "category": "minimal",
  "isPro": false,
  "canvas": { "width": 1080, "height": 1920, "fps": 30 },
  "duration": 6.0,
  "palette": {
    "background": "#0E0E10",
    "surface":    "#1C1C1F",
    "accent":     "#D9A441",
    "textPrimary":   "#FFFFFF",
    "textSecondary": "#B0B0B4"
  },
  "audio": { "defaultTrackId": "calm-01", "volume": 0.8 },
  "layers": [ ... ]
}
```

| Alan | Açıklama |
|---|---|
| `schemaVersion` | Format sürümü. Motor desteklemediği sürümü reddeder. |
| `id` | Global benzersiz, URL-güvenli. Deep link bununla çalışır: `app://sablon/minimal-fade-01`. |
| `name` | Lokalize ad (`en` zorunlu, diğerleri opsiyonel). |
| `category` | Galeri filtresini besler: `travel`, `social`, `business`, `promo`, `food`, `wedding`, `minimal`. Serbest metindir (sunucu yeni kategori yayınlayabilir); `TemplateCategory` bilinenlere sıra ve lokalize etiket verir. |
| `isPro` | Ücretsiz kullanıcıda kilitli mi. Manifest'te de tekrarlanır (galeri, dosyayı indirmeden bilmeli). |
| `canvas` | MVP'de hep 1080×1920 @30fps. Format alan olarak taşır ki ileride 1:1/4:5 eklenebilsin. |
| `duration` | Saniye. Toplam şablon süresi. |
| `palette` | Rol → hex (`#RRGGBB` veya `#RRGGBBAA`). Roller serbest isimli; katmanların referansladığı her rol var olmak zorunda (validasyon kuralı). |
| `overlay` | Sinematik overlay: `{ "vignette": 0-1, "grain": 0-1 }`. Tüm karenin üstüne uygulanır (kenar karartma + film tanesi). Yoksa efekt yok. |
| `audio` | Varsayılan müzik önerisi. Kullanıcı değiştirebilir; `defaultTrackId` telifsiz kütüphanemizdeki parça kimliği (`MusicLibrary`, aşağıya bkz.). `volume` 0–1. |
| `layers` | Çizim sırasına göre (ilk eleman en altta). |

## Katman ortak alanları

```json
{
  "id": "headline",
  "type": "text",
  "frame": { "x": 0.5, "y": 0.42, "width": 0.84, "height": 0.12 },
  "rotation": 0,
  "opacity": 1.0,
  "timing": { "start": 0.4, "duration": 5.6 },
  "animations": [
    { "role": "in",  "preset": "slideIn", "duration": 0.6, "delay": 0,
      "easing": "easeOut", "params": { "direction": "up", "distance": 0.06 } },
    { "role": "out", "preset": "fadeOut", "duration": 0.4 }
  ]
}
```

- `frame` — normalize; `x`,`y` **merkez** noktası, `width`,`height` kanvas oranı.
- `timing` — katmanın sahnede olduğu aralık (saniye). `start` yoksa 0, `duration`
  yoksa şablon sonuna kadar. Motor, aralık dışında katmanı görünmez yapar
  ("presence" mantığı animasyonlardan bağımsızdır).
- `animations` — `role`: `in` (start'ta), `out` (bitişten geriye hizalı), `loop`
  (aralık boyunca tekrar). `delay` role göre göreli. `easing`: `linear`, `easeIn`,
  `easeOut`, `easeInOut`, `spring`.
- `params` — preset'e özgü serbest sözlük. Motor bilmediği parametreyi yok sayar.

## Katman tipleri

### `shape`
```json
{ "type": "shape", "colorRole": "accent", "cornerRadius": 0.01 }
{ "type": "shape", "colorRole": "scrimClear", "cornerRadius": 0,
  "gradient": { "from": "scrimClear", "to": "scrimSolid", "direction": "down" } }
```
Dolgu rengi rolden. `cornerRadius` kanvas **yüksekliğine** normalize (tüm normalize
skaler değerler gibi).

`gradient` (opsiyonel) — iki palet rolü arasında doğrusal geçiş; verilirse
`colorRole` yerine bu çizilir. `direction`: `down` (varsayılan), `up`, `left`,
`right`, `diagonal`. Palet renkleri alfa taşıyabildiği için (`#00000000`)
"şeffaftan koyuya" scrim'ler bununla yazılır — düz renkli scrim şeridi kadrajı
sert bir bantla kesiyordu, metin okunurluğu için gradient tercih edin.

### `mediaSlot`
```json
{ "type": "mediaSlot", "slotIndex": 0, "media": "photoOrVideo",
  "contentMode": "fill", "mask": "rect", "cornerRadius": 0.02 }
```
- `slotIndex` — kullanıcının doldurduğu slotun sırası (editörde "1. medya" vb.).
  Şablon içinde benzersiz olmalı.
- `media` — `photo` | `video` | `photoOrVideo`.
- `mask` — `rect` | `circle` | `star` | `heart`. `star`/`heart` path tabanlı
  maskelerdir (MaskShape); medya bu şekle kırpılır. `contentMode` — MVP'de sadece
  `fill` (aspect-fill; kullanıcı kaydırma/zoom ile kadrajlar).
- `filter` (opsiyonel) — renk gradasyonu preset'i: `warm` | `cool` | `vintage` |
  `mono` | `vivid` | `cinematic` | `fade` (kendi ColorGrade CIFilter look'larımız).
  `filterIntensity` (0–1, varsayılan 1) orijinalle karışım oranı. Tanınmayan
  preset yok sayılır. Hem klasik foto hem montaj (foto/video) medyasına uygulanır.
- **Klasik (sahnesiz) kısıtı: en fazla 1 video slotu** (CoreAnimationTool yolu).
  Foto slotu sınırsız — birden çok maskeli foto (daire+kalp+yıldız kolajı) klasik
  yolda mümkün. Montajda sahne başına ≤4 video slotu.

### `text`
```json
{ "type": "text", "key": "headline",
  "default": { "en": "YOUR TITLE", "tr": "BAŞLIĞINIZ" },
  "font": { "name": "Archivo-SemiBold", "size": 0.045 },
  "colorRole": "textPrimary", "highlightColorRole": "accent",
  "alignment": "center", "maxLines": 2, "letterSpacing": 0.002, "allCaps": true }
```
- `key` — editörde alan etiketi ve analytics için stabil kimlik.
- `font.size` — kanvas yüksekliğine normalize (0.045 × 1920 ≈ 86pt).
- `font.name` — uygulamayla gömülü gelen 8–10 fonttan biri (PostScript adı).
  Motor, bulunamayan fontta sistem fontuna düşer, çökmez.
- `highlightColorRole` (opsiyonel) — metnin arkasına **satır bazlı renkli vurgu**
  (CapCut tarzı; her metin satırı kendi genişliğinde yuvarlak kutu). Değer bir
  palet rolü; `colorRole` de genelde vurgu üstünde okunur bir renge ayarlanır
  (ör. koyu metin + sarı vurgu). nil ise düz metin.
- **Emoji sticker:** `default` bir emoji (❤️ ✨ 🎉…) içerebilir — CoreText emoji'yi
  renkli render eder. `rotation` + `pop`/`scaleIn` animasyonuyla birlikte sticker
  etkisi verir; ayrı bir katman tipi gerekmez.

### `lottie`
```json
{ "type": "lottie", "asset": "confetti.json", "loopMode": "loop",
  "colorRemap": { "#FF0000": "accent" } }
```
- `asset` — şablon paketi içindeki dosya (aşağıda Paketleme).
- `colorRemap` — Lottie içindeki ham renk → palet rolü; renk şeması değişince
  animasyon da uyum sağlar.

## Animasyon preset'leri (MVP seti)

| Preset | Uygulandığı | Parametreler |
|---|---|---|
| `fadeIn` / `fadeOut` | hepsi | — |
| `slideIn` / `slideOut` | hepsi | `direction` (up/down/left/right), `distance` (normalize) |
| `scaleIn` | hepsi | `from` (ör. 0.8) |
| `pop` | hepsi | `overshoot` (ör. 1.06) |
| `kenBurns` | mediaSlot | `zoom` (ör. 1.12), `direction` |
| `wipeReveal` | hepsi | `direction` |
| `typewriter` | text | Gerçek daktilo: metin maskesi KARAKTER ADIMLARIYLA soldan açılır |
| `bounce` | hepsi | Yaylanarak yerleşme (birkaç sekme) |
| `pulse` | hepsi | Nabız (ölçek gidip gelir). `scale` (ör. 1.12), `axis` (`y` = yalnız dikey — dalga çubuğu) |
| `punchIn` | hepsi | Sert yaklaşma: büyükten hızla yerine oturur. `from` (ör. 1.6) |
| `spinIn` | hepsi | Dönerek yerleşme. `degrees` (ör. 12), `from` (ölçek) |
| `swingIn` | hepsi | Sallanarak asılma (rozet/sticker). `degrees` (ör. 14) |
| `floatLoop` | hepsi | Sürekli hafif süzülme. `distance` (normalize), `axis` (`x`/`y`) |
| `shake` | hepsi | Küçük titreşim (dikkat çekme). `degrees` (ör. 2.5) |
| `kineticWords` | text | **Kelime kelime giriş**: metin tek yerleşimden çıkar, her kelime kendi katmanında sırayla belirir. Tek kelimede etkisizdir (motor düz metne düşer) |

`kineticWords` NOTU: kelime katmanları `TextRasterizer.layout` ile tek bir
yerleşimden türetilir (satır kırılması, hizalama ve auto-shrink düz metinle
birebir aynı kalsın diye) ve her kelime **yerinde ölçeklenerek** girer. Dikey
yol alan giriş denendi ve `isGeometryFlipped` ağacında ara karelerde glifi
bölüyordu — açık iş olarak bırakıldı.

`role: loop` verilen animasyon katmanın **penceresi boyunca tekrar eder**
(nabız, dalga, süzülme, titreşim). `kenBurns` gibi süresi pencereye eşit olanlar doğal olarak bir
kez oynar.

Motor tanımadığı preset'te animasyonu atlar, katmanı statik gösterir. Böylece yeni
preset eklemek eski uygulama sürümlerini kırmaz (yalnızca yeni preset'i zorunlu
kılan şablonlarda manifest `minAppVersion` yükseltilir).

## Paketleme ve CDN manifesti

Galeri, tek bir manifest ile beslenir (`https://cdn.../v1/manifest.json`):
```json
{
  "manifestVersion": 1,
  "templates": [
    { "id": "minimal-fade-01", "version": 2, "category": "minimal",
      "isPro": false, "tags": ["popular"], "minAppVersion": "1.0.0",
      "template": "minimal-fade-01.json",
      "thumbnail": "thumbs/minimal-fade-01.jpg",
      "preview": "previews/minimal-fade-01.mp4",
      "name": { "en": "Minimal Fade", "tr": "Minimal Geçiş" } }
  ]
}
```
- **Manifest sırası = galeri sırası.** Sıralama, rozetler ve kilitler tamamen
  sunucudan yönetilir; uygulama güncellemesi gerekmez.
- `template`: şablon JSON'unun manifest'e göreli yolu (MVP dağıtım biçimi —
  şablonlar tek dosya). Verilmezse `templates/<id>.json` varsayılır.
- `tags`: `new` / `popular` — galeri etiketleri.
- `isPro`: galeri, dosyayı indirmeden kilidi bilmek zorunda olduğu için burada
  da tekrarlanır; şablonun içindeki `isPro` ile AYNI olmalı (test bunu doğrular).
- `version` artınca uygulama şablonu yeniden indirir (cache anahtarı `id-vN`;
  eski dosya bir sonraki tazelemede silinir). **İçerik değiştirdiysen sürümü
  elle artır**, yoksa cache'teki eski sürüm kullanılmaya devam eder.
- Uygulama sürümü `minAppVersion`'dan küçükse şablon galeride gizlenir →
  uygulama güncellemeden şablon yayınlama güvenli hale gelir.

Depodaki manifest `python3 tools/make-manifest.py` ile üretilir (mevcut sıra,
sürüm ve rozetleri korur; yeni şablonları sona ekler).

Lottie varlıkları depoda `templates/assets/` altında durur ve uygulama paketine
kopyalanır (`App/Scripts/copy-templates.sh`). Katmandaki `asset` alanı bu köke
göre yazılır: `"asset": "assets/confetti.json"`. Adaptör varlığı önce katalog
önbelleğinde, sonra uygulama paketinde arar; bulamazsa katman YER TUTUCU olur
(şablon kırılmaz).

`colorRemap` ham JSON üzerinde uygulanır (`LottieAssetRewriter`): `fl` (dolgu) ve
`st` (çizgi) katmanlarının `c` renk özelliği — sabit ve keyframe'li hâli.
GRADYAN dolgular (`gf`/`gs`) kapsam dışı: orada renk ile durak konumu tek dizide
iç içe yazılır, yanlış eşleşme animasyonu bozar. Gradyanlı bir varlıkta renk
uyumu isteniyorsa varlık düz renkle export edilmeli.

İleride CDN'den şablonla BİRLİKTE varlık indirmek için zip paket biçimi
(`package` alanı) eklenecek: `template.json` + `thumbnail.jpg` + `preview.mp4` +
`assets/`. Şu an lottie taşıyan şablon yalnız uygulama paketinden çalışır.

### İndirme davranışı (uygulama tarafı)

`TemplateCatalog` sırası her zaman **cache → seed → ağ**:
1. Uygulama, indirilmiş manifest/şablonlarla ağ beklemeden açılır.
2. Cache boşsa uygulamayla gelen (seed) şablonlar gösterilir → ilk açılış ve
   çevrimdışı çalışır.
3. Arka planda manifest tazelenir (`ETag`/`If-None-Match`; 304 gelirse cache
   korunur). Ağ hatası listeyi bozmaz, sadece tazeleme atlanır.

İndirilen şablon `TemplateValidator`'dan geçmeden cache'e yazılmaz — bozuk bir
yayın kullanıcıyı kilitleyemez, o şablon için elde olan sürüm kullanılır.

## Müzik kütüphanesi

`audio.defaultTrackId` **her zaman** kütüphanedeki bir parçayı göstermelidir
(test: `testEveryTemplateDefaultTrackExists`). Parça kimlikleri
`MusicLibrary.all` içinde tanımlıdır (ör. `calm-01`, `upbeat-01`, `beat-01`).

TASARIM KARARI (telif): parçalar dosya değil **tarif**tir — her biri bir
`MusicScore` (bpm, gam, akor dizisi, doku, bas/melodi/davul desenleri) ve
`AudioSynth` bunu çalışma anında istenen uzunlukta WAV'a sentezler. Sonuç:
lisans zinciri yok, depoda ses varlığı yok, uygulama boyutu artmaz, parça
video süresine birebir üretilir (loop kesme derdi yok). Sentez deterministiktir
(parça kimliğinden türetilen seed) — aynı parça her cihazda birebir aynı.

Her parçanın `isPro` alanı vardır; ücretsiz kullanıcıda kilitli parça seçilirse
export ücretsiz bir parçaya düşer (`Entitlements.resolvedTrack`).

## Ücretlendirme alanları

`isPro` (şablonda ve manifestte) tek kilit kaynağıdır. Kural motorda değil,
`Entitlements` içindedir:

| Durum | Şablon | Müzik | Filigran |
|---|---|---|---|
| Free | `isPro: false` olanlar | `isPro: false` parçalar | eklenir |
| Pro  | hepsi | hepsi | eklenmez |

Uygulama mağaza SDK'sını (RevenueCat/StoreKit) doğrudan kullanmaz;
`EntitlementProvider` protokolünü kullanır — paywall ve kilit mantığı SDK
olmadan test edilebilir.

## Sahneler (v2 — montaj şablonları)

`schemaVersion: 2` ile şablon üst düzeyde `duration`+`layers` yerine (ya da onlara
ek olarak) bir `scenes` dizisi taşıyabilir. Bu, hedef kitlenin yaptığı reel tarzı
montajı mümkün kılar: ardışık sahneler, sahne başına eşzamanlı çoklu video (kolaj),
sahneler arası geçişler.

```json
{
  "schemaVersion": 2,
  "id": "reel-collage-01",
  "canvas": { "width": 1080, "height": 1920, "fps": 30 },
  "palette": { "background": "#0B0B0D", "...": "..." },
  "scenes": [
    {
      "id": "collage",
      "duration": 4.0,
      "layers": [
        { "id": "band-top", "type": "mediaSlot", "slotIndex": 0, "media": "video",
          "frame": { "x": 0.5, "y": 0.1665, "width": 1.0, "height": 0.333 } },
        { "id": "band-mid", "type": "mediaSlot", "slotIndex": 1, "media": "video",
          "frame": { "x": 0.5, "y": 0.5, "width": 1.0, "height": 0.334 } },
        { "id": "band-bottom", "type": "mediaSlot", "slotIndex": 2, "media": "video",
          "frame": { "x": 0.5, "y": 0.8335, "width": 1.0, "height": 0.333 } }
      ],
      "transition": { "style": "blurDissolve", "duration": 0.6 }
    },
    { "id": "street", "duration": 4.0, "layers": [ ... ],
      "transition": { "style": "crossDissolve", "duration": 0.5 } }
  ],
  "layers": []
}
```

- **`scenes[].duration`** — sahnenin süresi. Katman `timing`'leri SAHNE zamanına
  görelidir (0 = sahne başı). Şablonun üst düzey `duration` alanı sahneli
  şablonlarda yok sayılır; toplam süre sahnelerden hesaplanır.
- **`scenes[].transition`** — bir SONRAKİ sahneye geçiş (son sahnede yok sayılır).
  - `style`: `cut` (örtüşme yok, sert kesme) | `crossDissolve` | `blurDissolve` |
    `slide`/`slideLeft`/`slideRight`/`slideUp`/`slideDown` (push kaydırma) |
    `zoomIn`/`zoomOut` (yaklaş/uzaklaş) | `whip` (hızlı bulanık kayma). Tanınmayan
    stil `cut`'a düşer (örtüşmez — güvenli varsayılan).
  - `duration`: geçiş penceresi (saniye). İki sahne bu kadar örtüşür.
    **Toplam süre = Σ sahne süreleri − Σ geçiş süreleri.**
- **Süreler serbest yazılır.** Sahne/geçiş süreleri saniye cinsinden istediğin
  değer olabilir; motor export'ta tüm zaman sınırlarını en yakın **kareye** oturtur
  (30fps'te ~0.033s ızgara). Böylece 0.25s gibi "yarım kare" süreler
  (AVFoundation aksi halde kompozisyonu reddeder) sorunsuz çalışır — şablon yazarı
  frame matematiği yapmak zorunda değildir.
- **Üst düzey `layers`** — sahneli şablonda TÜM montaj boyunca görünen global
  overlay katmanları (kalıcı logo, ilerleme çubuğu vb.); en üstte çizilir.
- **Kolaj** = aynı sahnede birden çok `mediaSlot`. Sahne başına en fazla 4
  video-alabilen slot (motor performans kısıtı, format değil).
- **Foto ve video karışabilir.** Montaj sahnelerinde `media: "photo"` slotları da
  desteklenir; foto'lar video ile aynı kolaj + geçiş (crossDissolve/blurDissolve)
  hattından geçer. Böylece foto slideshow (her sahnede 1 foto, geçişli) ya da
  karışık foto+video kolaj yapılabilir. `kenBurns` preset'i hem foto hem video
  slotlarında sahne boyunca yavaş zoom + yönlü kayma uygular.

## Validasyon kuralları (motor yüklerken kontrol eder)

1. `schemaVersion` destekleniyor (1–2).
2. Referanslanan her `colorRole` palette mevcut.
3. `slotIndex`'ler benzersiz.
4. `timing.start ≥ 0` ve katmanın penceresi kapsayıcı süreye (sahne ya da toplam)
   sığıyor (küçük taşmalar kırpılır, negatifler hata).
5. Katman `id`'leri benzersiz (kullanıcı metin düzenlemeleri `id` ile eşleşir).
6. Sahnesiz (v1) şablon: en fazla 1 video slotu (CoreAnimationTool yolu).
   `duration` zorunlu.
7. Sahneli (v2) şablon: `schemaVersion ≥ 2`; en az 1 sahne; sahne süresi > 0;
   geçiş süresi `0 ≤ d ≤ min(iki komşu sahne)/2`; sahne başına ≤ 4 video slotu.
