# Render Motoru Mimarisi — v2

## İki tür şablon, iki export yolu

Format v2'den itibaren iki tür şablon var:

- **Klasik (sahnesiz)** — tek sahne, grafik/metin/foto + en fazla 1 video.
  Tek geçişli CoreAnimationTool yolu (aşağıda). MVP'nin ilk şablonları böyle.
- **Montaj (sahneli, `scenes` alanı)** — hedef kitlenin yaptığı reel tarzı:
  ardışık sahneler, sahne başına AYNI ANDA birden çok video (kolaj bantları),
  sahneler arası geçişler (crossDissolve/blurDissolve). Bkz. "Montaj yolu".

İki yol da **aynı CALayer ağacını** grafik/metin/foto için kullanır (WYSIWYG).
Fark yalnızca videonun nasıl geldiğinde: klasikte tek track doğrudan, montajda
önce ayrı bir geçişte tek videoya düzleştirilip taban olarak.

## Tek cümlelik özet (grafik katmanı)

Şablon + kullanıcı düzenlemeleri → **tek bir CALayer ağacı** → aynı ağaç hem canlı
önizlemeyi hem MP4 export'unu üretir. Önizleme ile export'un birebir aynı olması
(WYSIWYG) bu tek-kaynak kuralından gelir; iki ayrı çizim yolu yazarsak eninde
sonunda ayrışırlar.

```
Template (JSON)  ─┐
UserEdits         ├─► TemplateLayerBuilder ─► CALayer ağacı
(medya, metin,    │         │                     │
 palet, müzik)   ─┘         │                     ├─► Önizleme: UIView.layer,
                            │                     │   CoreAnimation gerçek zamanlı
                    AnimationFactory              │   (speed/timeOffset ile scrub)
                    (preset → CAAnimation)        │
                                                  └─► Export: AVAssetExportSession +
                                                      AVVideoCompositionCoreAnimationTool
```

## Montaj yolu (sahneli şablonlar) — iki geçiş

Montaj şablonu iki geçişte export edilir (`TemplateExporter.export` yönlendirir):

1. **1. geçiş — `MontageComposer` + `MontageCompositor`:** Şablonun TÜM video
   içeriğini (sahne sıralaması, eşzamanlı kolaj slotları, geçişler, arka plan)
   tek bir ara MP4'e düzleştirir. Kareleri özel bir `AVVideoCompositing`
   (`MontageCompositor`, CoreImage tabanlı) üretir — bu yüzden CoreAnimationTool'un
   1-video sınırı burada GEÇERLİ DEĞİL. Zaman çizelgesi saf matematik olan
   `MontageTimeline`'dan gelir (sahne pencereleri + geçiş segmentleri).
2. **2. geçiş — kanıtlanmış CA hattı:** Ara video tam-kanvas taban olarak girer,
   grafik/metin/foto katmanları (aynı `TemplateLayerBuilder` ağacı) üstüne biner.

Neden iki geçiş, tek özel compositor'da her şey değil: metin/animasyon/Lottie
CoreAnimation dünyasında yaşıyor ve orada zaten kanıtlandı (v1). Onları CoreImage'a
taşımak tüm o işi çöpe atardı. Video kolajı ise CoreAnimation'da imkânsız. Her işi
en iyi olduğu hatta bırakıp iki videoyu zincirlemek en az riskli birleşim.

### MontageTimeline zaman modeli

Geçişler sahneleri **örtüştürür**: `crossDissolve`/`blurDissolve` süresi kadar iki
sahne üst üste biner; `cut` (ve tanınmayan stil → cut) örtüşme yaratmaz.
`totalDuration = Σ sahne süreleri − Σ geçiş süreleri`. Örtüşme iki komşu sahneden
de pay yer, bu yüzden validator geçiş süresini `min(iki sahne)/2` ile sınırlar
(üçlü örtüşme compositor'da tanımsız). Çizelge boşluksuz **segment**lere bölünür
(scene / transition); compositor talimatları birebir bu segmentlerdir.

### Geçiş harmanları (MontageCompositor.blend)

Geçiş segmentinde iki sahne (from/to) `blend(style:progress:...)` ile p∈[0,1]
harmanlanır:
- `crossDissolve` — CIDissolveTransition.
- `blurDissolve` — çan eğrisi Gaussian blur + dissolve.
- `slide*` — push: from bir yöne çıkar, to aynı yönden girer.
- `zoomIn`/`zoomOut` — merkeze ölçekleme + dissolve.
- `whip` — hızlı yatay kayma + yoğun motion blur (CapCut whip pan).
Tanınmayan stil crossDissolve'a düşer (overlap zaten varsayıldığı için güvenli —
`MontageTimeline.overlappingStyles` ile tutarlı). Yeni stil eklerken İKİSİNİ de
(overlappingStyles seti + blend switch) güncelle.

### MontageCompositor kare üretimi

Her karede: sahnenin arka plan rengi + aktif medya item'ları (normalize frame →
aspect-fill + kullanıcı kadrajı) `composited(over:)` ile üst üste. Bir `MediaItem`
video (track'ten `sourceFrame`) ya da foto (doğrudan `CIImage(cgImage:)`)
olabilir — ikisi de aynı hattan geçer, yani **foto slideshow/kolaj video ile aynı
kolaj + geçiş mekanizmasını** kullanır. Geçiş segmentinde iki sahnenin item'ları
ayrı kompoze edilip `CIDissolveTransition` ile harmanlanır; `blurDissolve` ek
olarak çan eğrisiyle (ortada max) Gaussian blur uygular. Şablon koordinatı
y-aşağı, CoreImage y-yukarı — dönüşüm compositor'da.

**Ken Burns:** `kenBurns` preset'i olan medya item'ları compositor'da
zaman-tabanlı işlenir — sahne penceresi boyunca 1→zoom yavaş büyüme + yönlü kayma
(compositionTime'a göre). Bu hem foto slideshow'u canlandırır hem video
montajdaki kenBurns'ü uygular (CoreAnimationTool 2. geçişte video slot olmadığı
için animasyonlar orada değil, burada). Diğer preset animasyonlar (slideIn, pop,
fadeIn...) grafik/metin katmanlarına ait ve 2. geçişte CoreAnimation ile işlenir.

### Sahne başına video limiti

Compositor performansı için sahne başına en fazla `maxVideoSlotsPerScene` (=4)
eşzamanlı video-alabilen slot (validator kuralı). Referans reel'i 3 bantlı kolaj
kullanıyor; 4 pratikte fazlasıyla yeterli. Bu bir motor kısıtı, format kısıtı değil.

## Neden AVVideoCompositionCoreAnimationTool (grafik katmanı için, Metal değil)?

İki yol vardı:

1. **CoreAnimationTool** — CALayer ağacını AVFoundation'ın export hattına verirsin,
   sistem her karede ağacı offscreen render eder. Az kod, animasyonlar deterministik,
   Lottie'nin CoreAnimation motoru da bu ağaca doğal oturur.
2. **Özel `AVVideoCompositing` + Metal** — her kareyi kendimiz çizeriz. Sınırsız güç
   (çoklu video, blend modları, shader efektleri), ama ciddi mühendislik + test yükü.

Grafik/metin katmanı için 1. yol; video kolajı için 2. yolun CoreImage sürümü
(`MontageCompositor`). İkisini iki geçişte zincirledik (yukarı).

MVP şablonları foto + metin + basit animasyon ağırlıklı → 1. yol yeterli.
**Bedeli tek kısıt: şablon başına en fazla 1 video slotu.** CoreAnimationTool'da
birden çok `videoLayer` aynı kompoze edilmiş kareyi gösterir; farklı videoları
farklı slotlara koymak track'leri önce kendimizin kompoze etmesini gerektirir —
bu da v1.1'de özel compositor işi. Şablon formatı bu kısıtı kural olarak taşıyor,
motor değişince kural gevşer, format değişmez.

## Bileşenler (TemplateKit paketi)

| Bileşen | Sorumluluk |
|---|---|
| `Template` (Model/) | JSON'un tip güvenli hali. Saf Foundation — UIKit'siz derlenir, testleri Mac'te koşar. |
| `UserEdits` (Model/) | Slot atamaları (medya + kadraj), metin değişiklikleri, palet, müzik. Taslak kaydetme = bunun serialize'ı. |
| `TemplateValidator` | Yükleme anı kuralları (format dokümanındaki 5 kural). |
| `TemplateLayerBuilder` (Render/) | Model → CALayer ağacı. Her katman bir **container** (presence/görünürlük penceresi) + **content** (asıl çizim) çiftidir; preset animasyonlar content'e, görünürlük penceresi container'a uygulanır ki çakışmasınlar. |
| `AnimationFactory` (Render/) | `AnimationSpec` → `[CAAnimation]`. Tanınmayan preset → boş liste (graceful degrade). |
| `TemplateExporter` (Render/) | AVMutableComposition + AVVideoComposition kurulumu, watermark, ilerleme, iptal. |

## Zaman modeli (en çok hata çıkan yer)

- Tüm animasyonlar **şablon zamanında** mutlak `beginTime` ile kurulur.
- Export'ta `beginTime = AVCoreAnimationBeginTimeAtZero + t` (0 geçersiz sayıldığı
  için sabit şart), `isRemovedOnCompletion = false`, `fillMode = .both` — üçünden
  biri unutulursa export'ta katmanlar kaybolur/zıplar.
- Önizlemede aynı ağaç `layer.speed = 0` + `timeOffset = t` ile scrub edilir;
  oynatma için `speed = 1`, `beginTime = CACurrentMediaTime()`.
- Builder'a `TimeOrigin` parametresi geçilir (`.export` / `.preview`) — tek fark bu.
- Ağaç kurulurken `CATransaction.setDisableActions(true)` (implicit animasyon sızıntısı
  export'ta kare kayması yapar).

## Export hattı, adım adım

1. `AVMutableComposition` kur:
   - Video slotu varsa: kullanıcının klibi (seçtiği başlangıç noktasından, şablon
     süresi kadar) video track olarak girer.
   - Video slotu yoksa: CoreAnimationTool en az bir video track ister →
     `BlankClipGenerator` ile çalışma anında üretilen (ilk export'ta bir kez,
     sonra cache) 1 sn'lik siyah klip şablon süresine uzatılarak girer.
     Bundle'a mp4 koymaya gerek yok.
   - Müzik: seçili parça audio track (başlangıç offset'i + şablon süresine kırpma
     + 0.5 sn fade-out).
2. `AVMutableVideoComposition`: `renderSize = 1080×1920`, `frameDuration = 1/30`.
3. `TemplateLayerBuilder` ile ağaç kur (`scale`: export'ta 1080 geniş, önizlemede
   view boyutu). Video slot katmanı, ağaçta boş `videoLayer` olarak yer alır;
   `AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayers: [videoLayer], in: root)`.
   Kullanıcının kadrajı (zoom/pan) layer instruction transform'una çevrilir.
4. Free kullanıcıda watermark katmanı root'a en üste eklenir (yarı saydam logo,
   sağ alt). Pro kontrolü exporter'a **parametre** olarak gelir — motor RevenueCat'i
   bilmez.
5. `AVAssetExportSession` (H.264, `.mp4`), `exportAsynchronously` + progress KVO →
   arka planda render, UI'da ilerleme çubuğu. İptal desteklenir.

Not — `isGeometryFlipped`: CoreAnimationTool CG koordinat sisteminde (y aşağıdan
yukarı) render eder; export root layer'ında `isGeometryFlipped = true` set edilir,
önizlemede edilmez. Builder değil, tüketen taraf set eder.

## Önizleme notları

- Foto slotları export ile birebir aynı (aynı ağaç).
- Video slotu önizlemede `AVPlayerLayer` ile gösterilir (export'taki videoLayer'ın
  yerine oturur), oynatma saati `CADisplayLink` ile ağaç saatine kilitlenir.
- Galeri "canlı önizleme"si render motoru DEĞİLDİR — CDN'den gelen `preview.mp4`
  oynatılır (ucuz, akıcı). Motor önizlemesi editörde devreye girer.

## Metin render'ı — CATextLayer DEĞİL, kendi rasterizer'ımız

Ampirik bulgu (2026-07-20, macOS 26, export_probe ile izole edildi):
**`CATextLayer`, CoreAnimationTool export hattında hiç render edilmiyor** — düz
string'le bile, flip'ten bağımsız; aynı ağaçtaki düz renk katmanı çıkarken metin
boş çıktı. Doğrudan `render(in:)` ile sorunsuz — yani sorun kompozisyon hattına
özgü.

Bu yüzden metin `TextRasterizer` (CoreText) ile CGImage'a çizilir ve katmana
`contents` olarak verilir — fotoğrafların kullandığı, export'ta kanıtlanmış yol.
Kazanımlar:
- Önizleme ve export piksel piksel aynı (rasterizasyonu biz kontrol ediyoruz).
- Kern, hizalama, satır düzeni tam kontrol (CATextLayer'ın sınırları yok).
- **Auto-shrink**: kullanıcı metni kutuya sığmıyorsa font sığana kadar küçülür
  (satır kırpmak yerine — kullanıcı metni serbest olduğu için şart).
- `allCaps` locale'li uppercase kullanır (Türkçe i → İ).

## Lottie

`lottie-ios`'un **CoreAnimation rendering engine**'i animasyonu CAAnimation'lara
derler → bizim ağacın içinde export'a doğal katılır. Main-thread motoruna düşen
Lottie özellikleri (bazı efektler) şablon üretiminde yasak listesindedir.

**Motor sınırı (`Render/LottieRendering.swift`):** `TemplateKit` bağımlılıksız
kalır — lottie-ios ayrı hedeftedir (`TemplateKitLottie`). `LottieRendering`
protokolü tek bir iş yapar: `LottieRequest` (asset, loop, çözülmüş renkler,
boyut, `baseTime`, `startTime`) → `CALayer`. `TemplateLayerBuilder` bu katmanı
kayıtlıysa ağaca ekler, kayıtlı değilse yer tutucuyla devam eder ve uyarı
verir; yani lottie taşıyan bir şablon indirilse bile uygulama kırılmaz.
`colorRemap` motorda çözülür (`LottieContent.resolvedColors(palette:)`:
ham hex → palet rolü → RGBA, bilinmeyen rol atlanır) — adaptöre hazır renkler
gider, adaptör palet sözleşmesini bilmez.

### Adaptörün üç şartı (sahada bulundu, hepsi export'ta sessizce kırılıyordu)

1. **CoreAnimation rendering engine.** Main Thread engine ekranda `displayLink`
   ile çizer; `AVVideoCompositionCoreAnimationTool` ağacı ekran dışında kendi
   zamanında örnekler → boş kare. (`CATextLayer`'ın aynı hatta hiç render
   edilmemesi bunun neden pazarlık konusu olmadığının kanıtı.)
2. **`display()` ELLE tetiklenmeli.** `play()` animasyonları kurmaz, kurulumu
   `display()` anına erteler — ekrandaki katman için CoreAnimation bunu kendisi
   çağırır, export ağacı hiç ekrana çıkmadığı için çağırmaz. Tetiklenmezse ağaç
   0 animasyonla kalır (belirti: video tamamen hareketsiz).
3. **Ölçek/konum İÇ katmana.** Aspect-fit'i `LottieAnimationView` yapıyor,
   `LottieAnimationLayer` yapmıyor; biz view değil katman kullanıyoruz. Dış
   katmanı ölçeklemek işe yaramaz — iç katman konumunu animasyonun kendi
   kanvasına göre kurar, sonuç YARIM KANVAS kayar. (Belirti aldatıcı:
   "animasyon geç başlıyor" gibi görünür, aslında içerik kadrajın dışındadır.)

Ardından tüm alt ağaçtaki animasyonların `beginTime`'ı `baseTime + startTime`e
kaydırılır (lottie hepsini `beginTime = 0` ile ekler, CoreAnimation'da 0
"ŞİMDİ" demektir; export'ta zaman sıfırdan başlar).

### Renk eşlemesi ham JSON üzerinde

`colorRemap` lottie-ios'un `setValueProvider(_:keypath:)` yolu yerine kaynak
JSON'da uygulanır (`LottieAssetRewriter`, TemplateKit içinde, bağımlılıksız ve
test edilebilir). Sebep: keypath yolu animasyonun İÇ YAPISINI bilmeyi ister
("Shape Layer 1.Group 1.Fill 1.Color"); bizim sözleşmemiz ise renge bağlı —
tasarımcı varlığı yeniden export edip katman adlarını değiştirse bile çalışmalı.
Kapsam: `fl`/`st` katmanlarının `c` özelliği (sabit + keyframe'li). Gradyanlar
bilerek dışarıda (renk ile durak konumu tek dizide iç içe).

## v1.1+ için kapılar (şimdiden açık bırakılan)

- Çoklu video slotu → özel `AVVideoCompositing` (format hazır, kural gevşetilir).
- `typewriter` ve karakter bazlı metin animasyonları → özel text layer.
- Keyframe animasyon → `AnimationSpec`'e `"keyframes"` alanı (preset'lerle yan yana).
