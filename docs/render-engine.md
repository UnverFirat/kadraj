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
| `TemplateLayerBuilder` (Render/) | Model → CALayer ağacı. Her katman bir **container** (presence/görünürlük penceresi) + **content** (asıl çizim) çiftidir; preset animasyonlar content'e, görünürlük penceresi container'a uygulanır ki çakışmasınlar. Ayrıca "hangi metin kullanıcının medyası üstünde" kararını verir (Okunabilirlik). |
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

### Plaka ve etiketi tek nesnedir

Bir rozetin dolgusu ile içindeki yazı ŞABLONDA iki ayrı katmandır, EKRANDA tek
bir nesnedir. Motor bunu bilmediği için her katman kendi `timing.start`'ına göre
giriyordu ve şablon yazarının 0,1–0,3 sn'lik kademesi ekranda **boş renkli bir
kutu** olarak görünüyordu (`sale-promo-01`: `cta-pill` 2,1 sn — `cta` 2,3 sn;
gerçek export'ta hap dolarken yazı henüz yoktu).

Tek şablonun hatası değildi: katalogdaki 136 dar plaka/etiket çiftinin
**135'inde** plaka etiketinden önce giriyor (medyan 0,12 sn). 127 JSON'a
dokunmadan düzeltilebilecek tek yer motor, o yüzden kural
`Layer.bindingPlatesToLabels` ile render listesinin kurulduğu yere
(`flattenedLayersForRender`) kondu — hem önizleme hem export aynı listeden
beslendiği için WYSIWYG bozulmaz.

- **Plaka etiketiyle aynı anda girer** (`plaka.start = etiket.start`), penceresinin
  SONU korunur (geç giren plaka geç çıkmaz).
- Ters yön (etiketi öne çekmek) DEĞİL: etiket plakanın dönüşümünü miras almaz
  (ayrı container'lar), plaka `bounce` ile 0,4 ölçekten büyürken yazı tam boyda
  durur ve hapın dışına taşar.
- **"Plaka" dar olmak zorunda**: metni saran ama ondan belirgin büyük bir kart
  (davetiye kartı, not kâğıdı) sahne dekorudur; etiketini beklerse tasarım
  çöker. Bu yüzden boyut farkı (≤0,12 genişlik / ≤0,09 yükseklik) ve mutlak
  yükseklik (≤0,25) sınırlanır, eğik plaka yalnız aynı açıdaki etiketle eşleşir.
- Saniyeler süren fark (>1 sn) kademe değil bilinçli kurgudur; motor karışmaz.
- Eşleşme sahne İÇİNDE aranır: farklı sahnelerin katmanları aynı kadrajda olsa
  bile aynı nesne değildir.

### Klip hızı (hızlandır / ağır çekim)

Kullanıcı her video slotu için bir hız çarpanı seçebilir
(`UserEdits.SlotAssignment.speed`, 0,25–4). **Hız videonun SÜRESİNİ
değiştirmez** — şablonun ritmi, sahne pencereleri ve müzik hizası sabit kalır;
değişen, pencereye sığdırılan KAYNAK bölümüdür:

| Hız | 3 sn'lik sahnede kaynaktan alınan | Etki |
|---|---|---|
| 0,5x | 1,5 sn | ağır çekim |
| 1x | 3 sn | normal |
| 3x | 9 sn | hızlandırılmış |

Uygulanışı iki yolda da aynı: `insertTimeRange` ile `pencere × hız` kadar kaynak
alınır, sonra `scaleTimeRange` ile pencereye yayılır.

- Montaj (v2): `MontageComposer` — slot slot, `edits.slots[i].speed`.
- Klasik (v1): `TemplateExporter.compositeAndExport` — taban klip.
- Kullanıcının KENDİ SESİ seçiliyse ses track'i de aynı oranda ölçeklenir
  (`AudioInput.speed`), yoksa görüntüyle ses saniyeler içinde ayrışır. Müzikte
  hız her zaman 1 ve ses track'i HİÇ ölçeklenmez (videodan kısa bir parça
  uzatılmamalı).
- Kaynak klip istenen bölümü karşılamıyorsa (5 sn'lik klip, 3x'te 9 sn isteniyor)
  eldeki bölüm pencereye yayılır — yani hız sessizce düşer, pencerede boşluk
  kalmaz.
- Aralık `SlotAssignment.clampSpeed` ile zorlanır: 0 veya NaN bir zaman aralığını
  sıfıra ölçekler ve AVFoundation kompozisyonu tümden reddeder.

Doğrulama `ClipSpeedTests`: zamanı PARLAKLIKLA kodlayan bir klip render edilip
çıktının verilen anındaki gri değeri kaynağın beklenen karesiyle karşılaştırılır
(hem montaj hem klasik yol).

### Aynı klip birden çok sahnede

Bir `slotIndex` birden çok sahnede geçebilir (ritimli şablonların temeli: tek
klip, dört kesme). Motor o klibi **kaldığı yerden sürdürür**
(`MontageComposer`'daki `consumed` haritası); klip tükenirse başa sarar.
Eskiden her sahne baştan oynattığı için aynı yarım saniye tekrar tekrar
takılıyordu ve tek klipten kurgu çıkarmak mümkün değildi.

### Kadraj ve kırpma başlangıcı

`CropTransform` ve `videoStart` iki yolda AYRI kodla uygulanıyor (montaj
CoreImage'da y-yukarı, klasik yol `CGAffineTransform` ile). İkisinin aynı anlama
geldiği ölçülerek doğrulandı — `CropAndTrimTests`: offsetY büyüdükçe görüntü
AŞAĞI kayar, offsetX büyüdükçe SAĞA, `scale` yakınlaştırır. Kullanıcı parmağını
aşağı sürükleyip şablon türüne göre farklı yöne kayan bir kadraj görmesin.

### Gönderi/kare oranı (4:5, 1:1)

Şablonlar 9:16 için tasarlandı ve koordinatlar normalize; kanvası değiştirmek
tipografiyi dikeyde sıkıştırır ve kompozisyonu çökertir. Bu yüzden oran
dönüşümü ŞABLONU DEĞİL BİTMİŞ VİDEOYU işler (`AspectReframer`): tasarım
olduğu gibi yeni kadraja sığdırılır (contain), artan alan aynı karenin
bulanık + hafif koyulaştırılmış kopyasıyla dolar. Tasarım riski sıfır;
`AspectReframerTests` hem boyutu hem "içerik kırpılmadı / kenar siyah bant
değil" iddialarını ölçüyor.

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

### Okunabilirlik: kullanıcının medyası üstündeki metin

Şablonun zemini paletle tasarlanır ve kontrastı bilinir; **medya slotunun
üstündeki metnin zemini kullanıcının fotoğrafıdır** ve bilinemez. Ölçülen bir
export'ta beyaz "YAZ İNDİRİMİ" başlığı açık renkli bir fotoğrafın üstünde
tamamen okunmaz çıktı — filigranın yıllar önce yaşadığı sorunun aynısı.

Çözüm de aynı (bkz. `TemplateExporter.makeWatermarkLayer` üstündeki gerekçe):
**palet tahmini ya da fotoğraf analizi değil**, yazının arkasına satır bazlı
koyu yarı saydam hap + tam opak yazı. Kareyi örneklemek işe yaramaz: parlaklık
her karede değişir ve "ortalama açık" bir karede koyu bir lekeye denk gelen
yazıyı kurtarmaz. Sabit hap her karede bir kontrast TABANI garanti eder — en
kötü durum bembeyaz bir fotoğraf: %45 siyah hap zemini ~0,55 griye indirir,
tam opak beyaz yazı ~3:1 kontrast tutar (büyük/kalın tipografi eşiği). Hapın
üstüne harflere yumuşak koyu bir hale eklenir; hale harfin KENARINI ayırdığı
için hap %45'te kalabiliyor (tek başına yeterli olması için ~%65 gerekirdi ve
o yoğunlukta kadraj kararıyordu). Hap rengi metnin KENDİ renginden türer
(açık yazı → siyah hap, koyu yazı → beyaz hap); eşik 0,5 değil **0,3**, çünkü
pembe/turuncu gibi doygun vurgu renkleri koyu zeminde parlar, açıkta çamura döner.

**Kime uygulanır** — `TemplateLayerBuilder.textsOverMedia`, ŞABLONUN KATMAN
SIRASINI yürüyerek "metnin altında ne var" durumunu taşır. Yön şudur: **yanlış
hap, kaçırılan haptan pahalıdır** (tasarımı bozar VE metni okunmaz yapar), o
yüzden şüphede kalan metne dokunulmaz.

| Katman | Etki |
|---|---|
| Taban videoya yakılmış medya (`prerenderedMediaRegions`) | slot KADRAJI kadar kapsama — "tüm kanvas" değil |
| Metinle kesişen `mediaSlot` | kesişim oranı kadar kapsama (birikmiş örtü sıfırlanır) |
| Metni tümüyle örten **tam opak** `shape` | zemin yeniden bilinir → kapsama 0 |
| Koyu **yarı saydam** `shape`/gradyan | örtüler `1 − Π(1−aᵢ)` ile birikir |
| `highlightColorRole` taşıyan metin | zaten opak vurgusu var → hap yok |
| Harf/rakam içermeyen metin (❤️ ✨ 🎉) | sticker → hap yok |

Hap ancak kapsama **≥ 0,85** ve birikmiş örtü **< 0,7** ise konur.

- **Neden kapsama oranı, "kesişim var mı" değil:** `makeup-look-01`'de sol
  etiketler portre slotuna `2,8e-17` birim değiyordu (`0,115+0,105` ile
  `0,5−0,28` ikili tabanda aynı sayı değil), sağdaki simetrikleri tam `0,0`
  çıkıyordu — poster sol/sağ asimetrik haplanmıştı. Eşiğin 0,85 olması
  `valentines-01`'in portre kenarına oturan dört kalbini de birlikte kurtarır
  (kapsamaları 0,55 ve 0,60; 0,6 eşiğinde yalnız biri hap alıyordu).
- **Neden taban videonun kapladığı alan değil slot kadrajı:** montajda sahne
  medya slotları düzleştirilmiş listede yoktur, ama taban videonun tüm kanvası
  doldurması "her yer medya" demek değildir — slot dışını sahne arka plan rengi
  doldurur. `spa-calm-01`'de medya üstteki %56'dır; alt yarısı krem düz zemindir
  ve oradaki üç metin (koyu yazı, krem zemin) haplandığında **hapsız halinden
  daha az okunuyordu**.
- **Örtü eşiği 0,7:** alfa `a`'lık siyah bir örtü en kötü durumu (bembeyaz kare)
  `1−a` parlaklığına indirir; beyaz yazının 3:1 kontrastı için
  `1,05/(L+0,05) ≥ 3 → L ≤ 0,3 → a ≥ 0,7`. Dikey gradyanların alfası metnin
  bandına göre hesaplanır (kutunun iki kenarından en zayıfı) — `sale-promo-01`'de
  alt kenardaki `@markanız` böyle kurtulur, kadrajın ortasındaki başlık kurtulmaz.

Karar `TemplateLayerBuilder.legibilityScrimTargets` ile ağaç kurmadan
sorulabilir; regresyon testleri DEPODAKİ şablonlar üzerinde KATMAN ADIYLA kilit
koyar (`spa-calm-01`/`makeup-look-01`/`valentines-01`/`sticker-fun-01` hap
ALMAZ, `sale-promo-01`'in başlığı ALIR). Bu kilitler olmadan bir tur görsel
regresyon üretildi: kare ölçen testler yeşilken posterlerde yanlış haplar
çıktı, çünkü yapay test şablonlarında o geometriler yoktu.

Şablon başına kapatılabilir: `Template.textLegibility` (`auto` / `off` /
`always`). Alan **opsiyoneldir**; yoksa `auto`. Bilinmeyen değer `auto`'ya
düşer (preset/geçiş stilleriyle aynı ileri uyumluluk kuralı). Doğrulama
`TextLegibilityTests`: bembeyaz fotoğrafın üstündeki beyaz metnin bandı
ölçülür — koruma kapalıyken standart sapma ~0 (metin yok gibi), açıkken
yüksek; düz renk zeminli ve opak kart üstündeki metinlerde ise kare **birebir
aynı** kalır.

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
