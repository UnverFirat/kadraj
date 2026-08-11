# Kadraj

iOS şablon-bazlı video oluşturucu (500 Stories / Mojo tarzı).
Stack: SwiftUI + AVFoundation/Core Animation + Lottie + RevenueCat + StoreKit 2.
MVP hunisi: **şablon seç → medya koy → export → öde.**

> **Ad:** ürün adı **Kadraj** olarak belirlendi (depo adı `kadraj`). Kodda
> kullanıcıya görünen ad hâlâ `StoryTemplate` — `AppInfo.displayName` +
> `CFBundleDisplayName` + ikon birlikte güncellenecek (bkz. [MAGAZA.md](MAGAZA.md)).
>
> **Mağazaya çıkış:** App Store Connect'in istediği her metin ve cevap
> [MAGAZA.md](MAGAZA.md) içinde. Yasal sayfalar `docs/` altında (GitHub Pages):
> [gizlilik](https://unverfirat.github.io/kadraj/gizlilik.html) ·
> [destek](https://unverfirat.github.io/kadraj/destek.html) ·
> [koşullar](https://unverfirat.github.io/kadraj/kosullar.html)
> — Pages açılmadan bu üç adres 404 verir, `Legal.swift` bunlara bakıyor.

## Depo yapısı

| Yol | İçerik |
|---|---|
| `docs/template-format.md` | Şablon JSON sözleşmesi (v2: klasik + montaj sahneleri) + CDN manifest formatı |
| `docs/render-engine.md` | Render motoru mimarisi (iki export yolu) ve kararların gerekçeleri |
| `docs/cdn-deployment.md` | **Ne pakette, ne sunucuda** — dağıtım kararı, yayınlama adımları, cache başlıkları |
| `templates/` | **127 şablon** + `manifest.json` (CDN'in tek giriş noktası). 14 kategori: sosyal, tanıtım, yemek, gezi, iş, moda, güzellik, spor, emlak, eğitim, müzik, kutlama, özel günler, minimal. 97 klasik (v1) + 30 montaj (v2); 64 Pro / 63 ücretsiz. Şablonların çoğu `tools/templates_src/` altındaki batch dosyalarından ÜRETİLİR (bkz. Şablon üretim hattı) — elle düzenlenen JSON'lar bir sonraki üretimde ezilir. |
| `templates/assets/` | Şablonların kullandığı Lottie animasyonları. ÜRETİLMİŞ: `tools/make-lottie-confetti.py` (hazır varlık indirmiyoruz — lisans zinciri olmasın) |
| `templates/thumbs/`, `templates/previews/` | Galeri varlıkları — manifest'in gösterdiği poster (jpg) ve önizleme (mp4). ÜRETİLMİŞ dosyalar: `templatekit-assets` ile yeniden çıkar |
| `TemplateKit/` | Swift paketi: model + validator + render çekirdeği + exporter + müzik + katalog + abonelik |
| `App/` | iOS uygulaması: `StoryTemplate.xcodeproj` + SwiftUI kabuk (şablonlar / videolarım / ayarlar) |
| `tools/make-lottie-confetti.py` | `templates/assets/confetti.json` üretici (parça sayısı/hız/renk parametrik, sabit tohum) |
| `tools/make-manifest.py` | `templates/manifest.json` üretici (sıra/sürüm/rozetleri korur) |
| `tools/templatelib.py` | Şablon üretim API'si + **lint** (motor kuralları + tasarım kontrolleri) |
| `tools/templates_src/` | Şablon batch dosyaları; `_reference.py` örnek düzenler ve kurallar (üretime girmez) |
| `tools/build-templates.py` | Batch'leri çalıştırıp `templates/*.json` yazar, hepsini lint eder |
| `tools/contact-sheet.py` | Posterleri tek görselde toplar (katalogu gözle denetlemenin tek yolu) |
| `tools/publish-cdn.sh` | CDN'e yüklenecek `dist/cdn/` ağacını hazırlar + tutarlılık doğrular |
| `templates/seed-posters.txt` | Uygulama paketine giren posterlerin listesi (gerisi CDN'den) |

## Uygulama (App/)

`App/StoryTemplate.xcodeproj` — Xcode'da aç ve çalıştır, ya da terminalden:

```
cd App && ./build.sh                    # derle + kur + başlat (simulator)
./build.sh --no-run                     # yalnız derle + kur
DEVICE=<udid> ./build.sh                # cihaz seç (ad belirsizse script uyarır)
./build.sh -- --route editor:quote-01 --pro     # "--" sonrası launch bayrağı
```

`App/Scripts/smoke.sh` kritik huniyi (galeri → editör → medya → export →
Videolarım → paywall → EN dili) simulator'da koşturur ve çökme raporu arar.

`build.sh` artık yalnız `xcodebuild` + `simctl` sarmalayıcısı: derlemenin tek
kaynağı Xcode projesi, yani Xcode'da açtığında ve terminalde koştuğunda aynı şey
derlenir. TemplateKit projeye **yerel SPM paketi** olarak bağlı (`../TemplateKit`)
— uygulama gerçek bir modül sınırının arkasında (`import TemplateKit`), eskisi
gibi tek modülde birleştirilmiyor. Bundle id: `com.storytemplate.app`.

Şablonlar bundle'a bir Run Script fazıyla **depo `templates/` klasöründen**
kopyalanır (tek kaynak, `App/Scripts/copy-templates.sh`); bu kopya katalogun
"seed"idir — yeni şablon eklemek için Xcode projesine dokunmak gerekmez.

**Kabuk (3 sekme):**

| Sekme | İçerik |
|---|---|
| Şablonlar | galeri (127 şablon, 14 kategori, arama + kategori filtresi, kategoriye bölünmüş bölümler, üretilmiş posterler, aşağı çekince yenilenir) → editör → "Video Oluştur" (gerçek `TemplateExporter`) → tam ekran sonuç ekranı |
| Videolarım | oluşturulan videolar kalıcı (`Application Support/Exports` + poster karesi); oynat / Fotoğraflar'a kaydet / paylaş / sil (onaylı) |
| Ayarlar | abonelik durumu + yönet, satın alımları geri yükle, değerlendir / arkadaşına öner / destek, yasal bağlantılar, sürüm |

Editör biten export'u geçici klasörden `ExportLibrary`'ye alır — video uygulama
kapanınca kaybolmaz. Paywall her sekmeden aynı yoldan açılır (`Store.showPaywall`).

**Editör düzeni (`EditorView`):** ekranın büyük kısmı 9:16 sahnedir; düzenleme
kontrolleri altında SABİT yükseklikli tek bir panelde ve üç sekmede toplanır
(Medya / Metin / Müzik). Sekme çubuğu bu ekranda gizlenir
(`.toolbar(.hidden, for: .tabBar)`) — düzenleme bir görev akışı, kullanıcı işin
ortasında başka sekmeye davet edilmemeli. Daha önce sahne, dikey bir formla ve
sekme çubuğuyla aynı `VStack`'i paylaşıyordu: kadraj 430 pt'lik ekranda 174 pt'ye
düşüyor ve formun SON alanı eylem çubuğunun altında kalıp hiç erişilemiyordu.

Boş editörde sahne **galeri posterini** gösterir (kullanıcının kartta dokunduğu
görselin aynısı) — şablonun boş slotlarla çizilmiş hali çoğu montajda bomboş bir
gradyan veriyordu. Medya seçilir seçilmez `TemplatePreview`'a geçilir.

Metin alanlarının başlıkları `TextFieldLabels` tablosundan gelir (katman
id'lerini "Ana başlık", "Fiyat", "Adım 2" gibi kullanıcı diline çevirir);
tabloda olmayan id (ör. CDN'den inen yeni şablon) "Metin N"e düşer.

**Sonuç ekranı (`ExportResultView`):** export bitince tam ekran açılır — büyük
oynatıcı, "Videon hazır · Videolarım'a kaydedildi", Kaydet / Paylaş, ücretsiz
kullanıcıya "Filigranı kaldır", ve iki çıkış (Düzenlemeye dön / Yeni video).
Kapanınca `flow.phase` `.idle`'a çekilir; eskiden faz `.done`'da kaldığı için
export sonrası metnini değiştiren kullanıcı videoyu bir daha oluşturamıyordu.

Deep link: `storytemplate://sablon/<id>` şablon sekmesinde o şablonun editörünü
açar (katalogda yoksa "şablon bulunamadı" ekranı).

Launch bayrakları (screenshot otomasyonu ve senaryo denemesi):

| Bayrak | Etki |
|---|---|
| `--route editor:<id>` / `preview:<id>` | doğrudan editöre / otomatik export+önizlemeye |
| `--cdn <url>` | şablonları CDN'den çek (yoksa yalnız paket şablonları) |
| `--pro` / `--free` | Pro başlat / aboneliği sıfırla (yalnız `local` ödeme arka ucunda) |
| `--billing local` / `storekit` | ödeme arka ucu (varsayılan `local`: mağazasız demo) |
| `--open-videos`, `--open-settings` | ilgili sekmeyle başla |
| `--open-music`, `--open-paywall`, `--open-picker`, `--inject-media` | ilgili ekranı aç / seçimi taklit et |

**Galeri kartı:** `templatekit-assets` ile üretilmiş poster (`thumbs/*.jpg`)
gösterilir; poster katalogla aynı yoldan gelir (CDN → önbellek → uygulama
paketi, aynı `id-vN` sürümlemesi, `ThumbnailStore`). Poster yoksa ya da henüz
inmediyse kart `TemplatePreview` ile **şablonun kendi katmanlarından** çizilir —
uygulamanın hiç tanımadığı bir CDN şablonu bile boş kart göstermez.

**Editör önizlemesi (oynayan + scrub):** editör açılınca şablon küçük
çözünürlükte (360×640, 20 fps) **motorun kendisiyle** ön-render edilir ve
oynatılır; `PlayerScrubView` ile duraklat/kareye git yapılabilir. Bu, README'de
açık kalan "canlı CoreImage mi, ön-render mi" kararının kapanışıdır: ön-render
seçildi çünkü (1) önizlemede görülen kare export'takiyle aynı motordan çıkıyor
(ikinci bir render yolu yok), (2) montajda 4 eşzamanlı video + geçiş canlı
sürüldüğünde cihazda kare düşüyor, (3) scrub bedava geliyor. Bedeli: metin/medya
değişince önizleme bayatlar — kart üstünde "Önizlemeyi yenile" çıkar (her tuş
vuruşunda yeniden render etmek kabul edilemezdi).

**CDN'i yerelde denemek:**
```
cd templates && python3 -m http.server 8765
cd App && ./build.sh -- --cdn http://localhost:8765
```
Katalog kaynağı ("uygulama paketi" / "önbellek (çevrimdışı)" / "güncellendi")
**Ayarlar → Geliştirici (debug)** bölümünde görünür; yayın derlemesinde bu bölüm
hiç derlenmez. (Eskiden galeri başlığının altında ve Ayarlar'da herkese
gösteriliyordu: CDN de önbellek de kullanıcının bilmesi gereken şeyler değil.)
Sunucu kapalıyken uygulama önbellekten açılır — CDN'den gelen ama uygulamayla
gelmeyen şablonlar dahil.

**Galeri erişimi (PHPicker):** Editörde medya slotuna dokununca sistem foto/video
seçici açılır (`MediaPicker`, PHPicker). Seçilen medya slota atanır, önizleme +
thumbnail anında güncellenir, "Video Oluştur" o medyayla export eder. PHPicker
izin gerektirmez (kullanıcı yalnızca seçtiğini paylaşır). Slot `video` dese bile
seçici FOTOĞRAFI da gösterir (motor her slotta fotoğrafı destekliyor; yalnız
video filtresi, galerisinde video olmayan kullanıcıyı "Video Yok" ekranında
çıkmaz sokağa sokuyordu); yalnız `photo` diyen slot gerçekten fotoğrafla
sınırlıdır. Dosya okunamazsa (iCloud'dan inmemiş video, desteklenmeyen biçim)
editör açıklayıcı bir uyarı gösterir — eskiden bu yolda hiçbir şey olmuyordu.
Screenshot otomasyonu için `--open-picker` (seçiciyi aç) ve `--inject-media`
(seçimi taklit et) bayrakları.

**Simulator kısıtı:** montaj export'unun 2. geçişi (CoreAnimationTool + gerçek
video decode) simulator GPU'sunun IOSurface havuzunu tüketip çöküyor (cihazda
sorun yok). Simulator'da montaj önizlemesi = 1. geçiş kolaj videosu + canlı
SwiftUI metin overlay'i (`MontagePreviewOverlay`). Klasik şablon simulator'da
uçtan uca tam export ediyor.

## TemplateKit

```
swift build && swift test   # Mac'te koşar (paket iOS + macOS hedefli)
```

- `Model/` — saf Foundation, Codable şablon modeli, `UserEdits`, `MontageTimeline`
  (sahne/geçiş zaman matematiği), validator.
- `Render/` — `TemplateLayerBuilder` (model → CALayer ağacı), `AnimationFactory`
  (preset → CAAnimation), `TextRasterizer` (CoreText → CGImage; CATextLayer export
  hattında render edilmediği için), `TemplateExporter` (klasik tek geçiş VE montaj
  iki geçiş), `MontageComposer`/`MontageCompositor` (çoklu eşzamanlı video +
  geçişler, CoreImage), `BlankClipGenerator` (taban klip, çalışma anında).
- `TemplateKitLottie` (AYRI HEDEF) — `LottieAdapter`, `LottieRendering`'in
  lottie-ios ile gerçeklenmesi. Çekirdek hedef (`TemplateKit`) bağımlılıksız
  kalsın diye ayrı; uygulama, her iki CLI ve testler aynı adaptörü bağlar
  (adaptör uygulamada kalsaydı poster/önizleme üreteci lottie'yi çizemezdi).
- `Audio/` — `MusicLibrary` (21 telifsiz parça), `MusicScore` (tarif: bpm/gam/
  akor/desen), `AudioSynth` (tarif → stereo PCM → WAV, çalışma anında,
  deterministik). Synth: zarf modülasyonlu alçak geçiren filtre + ADSR + ayrı
  davul sentezi + reverb/delay + groove/velocity + master (kompresör/limiter).
  Tını değişirse `AudioSynth.version` artırılmalı — cache anahtarında.
- `Catalog/` — `TemplateManifest` + `TemplateCatalog` (şablon VE poster indirme,
  disk cache, `id-vN` sürümleme, ETag/304, `minAppVersion` süzgeci, çevrimdışı
  geri düşüş, doğrulamayı geçmeyen içeriği cache'lememe).
- `Billing/` — `Entitlements` (kilit kuralları tek yerde), `EntitlementProvider`
  protokolü ve üç uygulaması: `LocalEntitlementProvider` (mağazasız, demo/test),
  `StoreKitEntitlementProvider` (StoreKit 2 — ürünler, satın alma, geri yükleme,
  `Transaction.updates` dinleyicisi), `RevenueCatEntitlementProvider`
  (`PurchasesBridge` protokolü üzerinden — SDK'sız test edilebilir).
  `EntitlementCache` son bilinen durumu diske yazar: mağaza cevabı gecikirken
  Pro kullanıcı bir an "free" görünmesin.
- `Analytics/` — `AnalyticsEvent` (huni olayları), `AnalyticsSink` protokolü,
  konsol + tampon sink'leri. Olaylar yalnız KİMLİK ve sayı taşır; kullanıcı
  metni, dosya yolu, cihaz kimliği hiçbir olayda yok (hesapsız uygulama,
  kimliksiz analitik).

Uçtan uca kanıt (Mac'te, simülatörsüz):

```
swift run templatekit-demo                          # montaj (reel-collage-01)
swift run templatekit-demo ../templates/minimal-fade-01.json   # klasik
swift run -c release templatekit-demo --music       # 21 parçayı WAV olarak yaz (dinlemek için)
swift run -c release templatekit-demo --music calm-01 30        # tek parça, 30 sn
# şablonu MP4'e export eder + kontrol karelerini demo-output/'a PNG yazar.
# Montaj yolunda video slotları için sentetik etiketli test klipleri üretir.
```

**Galeri varlıkları** (`templates/thumbs/*.jpg` + `templates/previews/*.mp4`):

```
swift run -c release templatekit-assets                  # 127 şablon, ~115 sn
swift run -c release templatekit-assets --only quote-01
swift run -c release templatekit-assets --lang en --width 720 --bitrate 1200000
```

Manifest bu iki yolu zaten yayınlıyordu ama dosyalar yoktu — CDN kırık link
veriyordu. Üreteç şablonun KENDİ varsayılan metinleriyle render eder (elle
yazılmış vitrin içeriği yok), slotları depodaki örnek kliplerle doldurur,
filigransız/sessiz export alır ve galeri için ~900 kbps'e indirir (ürün
export'u `HighestQuality` kalır — o kullanıcının videosu). Poster karesi
sabit bir orandan değil, **metin katmanlarının ekranda olduğu anlar arasından
en net olanından** seçilir: sabit oran montajda geçişin ortasına düşüp bulanık
kare veriyor, `fast-cut` gibi metni yalnız ilk/son sahnede olan şablonlarda da
şablonu hiç tanıtmayan kare çıkarıyordu.

### Şablon üretim hattı (`tools/`)

Katalog 100 şablona çıkarken şablonları elle JSON yazmak bırakıldı; artık
üretim hattı var:

```
tools/templatelib.py          # üretim API'si + LINT
tools/templates_src/*.py      # batch dosyaları (her biri bir tema kümesi)
tools/templates_src/_reference.py   # 6 örnek düzen + tasarım kuralları (üretime girmez)
tools/build-templates.py      # batch'leri çalıştır → templates/*.json + lint
tools/contact-sheet.py        # posterleri tek görselde topla (göz kontrolü)
```

```
python3 tools/build-templates.py            # hepsini üret + lint
python3 tools/build-templates.py yeme       # tek batch
python3 tools/build-templates.py --lint-only  # elle yazılmışlar dahil hepsini denetle
python3 tools/make-manifest.py
cd TemplateKit && swift run -c release templatekit-assets           # posterler (tr)
                  swift run -c release templatekit-assets --lang en # posterler (en)
python3 tools/contact-sheet.py              # bütün posterleri birkaç sayfada gör
```

**Lint neden var:** 127 şablonu kare kare göz kontrolünden geçirmek mümkün
değil. `lint()` motorun `TemplateValidator` kurallarını (palet rolü, benzersiz
katman/slot kimliği, sahne süresi, geçiş penceresi, v1'de tek video slotu)
Python'da tekrarlar ARTI gözle görülmeyen tasarım hatalarını yakalar: kadraj
dışına taşan katman, okunmayacak kadar küçük font, aynı anda üst üste binen
metin blokları, eksik iki dilli varsayılan, tanınmayan müzik parçası.

**En pahalı kural — montajda katman sırası:** motor montajı iki geçişte üretir
(1: medya slotları, 2: shape+text ONUN ÜSTÜNE). Yani sahne içinde yazdığın
sıra medya ile shape arasında geçerli DEĞİLDİR; sahneye `bg()` koyarsan tüm
videoyu kapatır. Bu tuzağa üretim sırasında 15 şablonda birden düşüldü
(hepsi bomboş render oldu) — lint artık hem tam kadraj zemini hem de
"fotoğraftan büyük arkalık kart" düzenini reddediyor, ikincisi klasik (v1)
şablon olmak zorunda.

Yeni şablon eklediğinde: batch dosyasına yaz → `build-templates.py` →
`make-manifest.py` → `templatekit-assets` → `contact-sheet.py` ile bak →
CDN'e yükle.

Temel ilke: **tek katman ağacı** grafik/metin için hem önizlemeyi hem export'u
üretir (WYSIWYG); video kolajı ayrı bir CoreImage geçişinde düzleştirilir.
Detaylar `docs/render-engine.md`'de.

## Durum / sıradaki işler

- [x] Şablon JSON formatı v1 + validasyon kuralları
- [x] Codable model + testler
- [x] Render çekirdeği: layer builder, animasyon fabrikası, presence sistemi
- [x] Export hattı (CoreAnimationTool, watermark, müzik + fade-out)
- [x] Metin: CoreText rasterizer + auto-shrink + locale'li allCaps
- [x] Blank klip üretici (çalışma anında; bundle mp4 gerekmez)
- [x] Uçtan uca export doğrulaması — macOS headless, kare kare görsel kontrol
      (foto + kenBurns, presence pencereleri, giriş/çıkış animasyonları, metin,
      filigran; `templatekit-demo`)
- [x] **Montaj motoru (v2):** sahne sistemi + eşzamanlı çoklu video kolajı +
      geçişler (cut/crossDissolve/blurDissolve). Hedef kitlenin reel tarzı.
      Kolaj, geçiş harmanı ve tam-ekran sahneler kare kare doğrulandı.
- [x] **12 şablon** (yukarıdaki tablo) — CapCut tarzı çeşitlilik: kolaj, ritim
      kurgu, 2×2 grid, ikiz ekran, foto slideshow, sinematik intro, alıntı kartı,
      kinetik tipografi, geri sayım, top-5 liste, polaroid, minimal. Hepsi macOS'ta
      kare kare doğrulandı. Montaj süreleri motorda kareye snap edilir.
- [x] **Foto montaj + Ken Burns:** MontageComposer artık foto slotları da
      işliyor (video ile aynı kolaj + geçiş hattı) → foto slideshow/kolaj mümkün.
      kenBurns (yavaş zoom + pan) compositor'da zaman-tabanlı uygulanıyor; hem
      slideshow'u canlandırır hem video montajlardaki kenBurns'ü (önceden sessizce
      atlanıyordu) düzeltir.
- [x] **Metin vurgu arka planı (highlight):** TextRasterizer satır bazlı renkli
      vurgu çiziyor (CapCut imzası) — `text.highlightColorRole`. Manşet/haber
      tarzı şablonların temeli.
- [x] **Galeri erişimi (PHPicker):** editörde slota dokun → sistem foto/video
      seçici → medya slota atanır → export o medyayla çalışır (App/MediaPicker).
- [x] **Medya maskeleri + sticker:** `mask: star|heart` (MaskShape, path tabanlı
      CAShapeLayer mask); emoji sticker (text + rotation, CoreText renkli emoji).
- [x] **Zengin geçişler + karışık medya:** slide/push, zoomIn/Out, whip geçişleri
      (MontageCompositor.blend). Aynı montaj şablonunda foto + video slotları
      karışık (`travel-mix`) — DemoLibrary slot medya tipine göre otomatik besler.
- [x] **Motor derinliği (1/3 aşama):** montaj medyasında maske (CoreImage alfa
      maskesi — daire/yıldız/kalp artık kolajda da), sinematik overlay
      (`overlay: {vignette, grain}` — EffectOverlay), gerçek daktilo (`typewriter`,
      karakter adımlı maske) ve `bounce` animasyonu.
- [x] **Renk gradasyonu (filtreler):** kendi CIFilter look'larımız — warm, cool,
      vintage, mono, vivid, cinematic, fade (ColorGrade). Slot bazlı `filter` +
      `filterIntensity`; klasik foto ve montaj medyasına uygulanır. Telif-güvenli
      (jenerik isimler, kendi implementasyon).
- [x] **Müzik kütüphanesi (telifsiz):** 21 parça, dosya değil TARİF —
      `MusicScore` + `AudioSynth` çalışma anında istenen uzunlukta sentezler
      (lisans zinciri yok, depoda ses yok, loop kesme yok). Editörde ruh haline
      göre gruplu seçici + dinleme; export'a AAC olarak gömülür (uygulamada ve
      macOS CLI'da doğrulandı; spektrumda akor/oktav tepe frekansları ölçüldü).
- [x] **CDN katalog + cache:** `manifest.json` (sıra, rozet, `isPro`,
      `minAppVersion`, `version`) + `TemplateCatalog` (cache → seed → ağ,
      ETag/304, `id-vN` sürümleme + eski dosya temizliği, doğrulamadan geçmeyen
      şablonu cache'lememe). Simulator'da yerel http sunucudan uçtan uca
      kanıtlandı: uygulamanın hiç tanımadığı şablon galeriye düştü, sunucu
      kapanınca önbellekten açıldı, `minAppVersion` süzgeci gizledi.
- [x] **Paywall + abonelik:** `Entitlements` (kilit kuralları tek yerde) +
      `EntitlementProvider` protokolü — RevenueCat/StoreKit adaptör seam'i,
      SDK'sız test edilebilir. 13 Pro / 8 ücretsiz şablon, Pro müzikler,
      free'de filigran (Pro export'ta filigransız olduğu simulator'da doğrulandı).
- [x] **Xcode app projesi + SwiftUI kabuk:** `App/StoryTemplate.xcodeproj`
      (TemplateKit yerel SPM bağımlılığı, şablonlar Run Script ile paketleniyor,
      paylaşılan scheme, app icon + accent). Kabuk üç sekme: şablonlar /
      videolarım / ayarlar. "Videolarım" export'ları kalıcı saklar (poster karesi,
      oynat/paylaş/sil) — video artık uygulama kapanınca kaybolmuyor.
      Simulator'da uçtan uca doğrulandı; Release derlemesi cihaz için (arm64) de
      geçiyor. `build.sh` xcodebuild sarmalayıcısına dönüştü (tek derleme kaynağı).
- [x] **Gerçek mağaza adaptörü + analytics:** `StoreKitEntitlementProvider`
      (StoreKit 2, SDK'sız) ve `RevenueCatEntitlementProvider`
      (`PurchasesBridge` seam'i, 9 test) — uygulama `--billing storekit` ile
      gerçek mağazaya bağlanır, varsayılan hâlâ `local` (App Store Connect'te
      ürünler tanımlanana kadar demo/screenshot akışı kırılmasın; ürünler
      yayına girince `BillingBackend.resolved`'ın varsayılanı değişir).
      Ürünler gelmeden paywall fiyat UYDURMAZ ("Fiyatlar yükleniyor…", buton
      kapalı — simulator'da doğrulandı). Analitik: huni olayları (şablon açıldı,
      medya seçildi, müzik, export başladı/bitti/hata, paylaşım, paywall, satın
      alma, geri yükleme) `Analytics` cephesinden geçer; DEBUG'da Ayarlar'da
      "son olaylar" listesi var. Ürün sağlayıcısı (Firebase/PostHog/kendi
      backend) seçildiğinde tek yapılacak bir `AnalyticsSink` adaptörü.
- [x] **Önizleme view'ı (scrub/oynatma):** editörde şablon küçük çözünürlükte
      ön-render edilip oynatılıyor; `PlayerScrubView` (AVPlayerLayer + kendi
      kontrolleri, tolerance-sıfır seek). Montajda kolaj videosu + canlı metin
      overlay'i aynı oynatıcıda. Bekleyen mimari karar ön-render lehine kapandı
      (gerekçeler yukarıda).
- [x] **Galeri posterleri bağlandı:** kartlar `thumbs/*.jpg` gösteriyor
      (katalogdan: CDN → önbellek → paket; poster yoksa `TemplatePreview`'a
      düşüyor). Posterler artık uygulama paketine de giriyor (~3 MB);
      `previews/*.mp4` (~17 MB) bilerek paketlenmiyor.
- [ ] Gerçek iOS cihazda export smoke testi (motor macOS'ta doğrulandı)
- [x] **Lottie (uçtan uca):** `LottieRendering` protokolü + `LottieAdapter`
      (ayrı `TemplateKitLottie` hedefi, lottie-ios 4.6). Şablonun `colorRemap`
      alanı animasyonun HAM JSON'unda uygulanır (`LottieAssetRewriter`) —
      lottie-ios'un keypath'e dayalı renk API'si yerine renge dayalı sözleşme:
      tasarımcı varlığı yeniden export edip katman adlarını değiştirse bile
      çalışır. Export hattının üç şartı adaptörde: CoreAnimation rendering
      engine, `display()`in ELLE tetiklenmesi (yoksa ağaçta hiç animasyon
      olmaz), ve ölçek/konumun İÇ katmana uygulanması. `celebrate-01` şablonu
      macOS'ta kare kare + simulator'da uçtan uca doğrulandı; renderer takılı
      değilken katman yer tutucu olur, şablon kırılmaz. 10 test.
- [x] **Şablon thumbnail/preview üretimi:** `templatekit-assets` — her şablon için
      poster (jpg) + önizleme (mp4), ~20 sn, 19 MB. Manifest'in gösterdiği
      `thumbs/`+`previews/` yolları artık gerçekten var (yerel http sunucudan
      HTTP 200 doğrulandı); 28 poster kontak baskısıyla gözle kontrol edildi.
      Lottie taşıyan şablonun posteri de animasyonlu çıkar (üreteç adaptörü bağlar).
      KALAN: gerçek CDN'e yükleme (galeri bağlantısı yapıldı — aşağıya bak).
- [x] **Aşama 3 — şablon zenginliği:** 7 niş şablon (tarif, emlak turu, menü,
      indirim, davetiye, müşteri yorumu, podcast) → 28 şablon; hepsi macOS'ta kare
      kare doğrulandı. Kategori sistemi (`TemplateCategory`) + galeri filtresi.
      Motor eklemeleri: `gradient` shape (yumuşak scrim), `pulse` preset ve
      `role: loop` artık gerçekten tekrar ediyor (dalga/nabız animasyonları).
      Genel `TemplatePreview` (şablonu katmanlarından çizen önizleme).
- [x] **Aşama 6 — kullanıcı gözüyle UI/UX geçişi:** uygulama uçtan uca
      simulator'da gezilip müşteri gözüyle denetlendi. Düzeltilen üç GERÇEK
      hata: (1) export sonrası faz `.done`'da kaldığı için metnini değiştiren
      kullanıcı videoyu yeniden oluşturamıyordu; (2) editörün formu eylem
      çubuğunun altında kırpılıyordu, son metin alanına hiç ulaşılamıyordu;
      (3) `video` slotu için seçici yalnız videoları gösterip galerisinde video
      olmayan kullanıcıyı "Video Yok" ekranında bırakıyordu. Ayrıca: editör
      düzeni yeniden kuruldu (sahne ~%75 büyüdü, kontroller üç sekmeli panelde,
      sekme çubuğu gizli), tam ekran "Videon hazır" sonuç ekranı eklendi,
      boş editör galeri posterini gösteriyor, galeriye arama + aşağı-çek-yenile
      geldi ve kart rozetleri üçten bire indi, kart alt satırı iç sözlükten
      ("Montaj • 3 sahne") kullanıcı diline geçti ("5 klip · 10 sn"), metin
      alanı başlıkları `TextFieldLabels` ile anlamlandırıldı, katalog/CDN
      göstergeleri DEBUG'a çekildi, Ayarlar'a değerlendir/öner/aboneliği yönet
      eklendi, paywall'a kapatma düğmesi + "en avantajlı" + güven satırı,
      müzik seçicide dinleme ve seçme ayrıldı ("116 BPM" → "Hareketli"),
      video silme onaya bağlandı, oynatıcı kontrolleri oynarken soluyor
      (filigranın üstünü kapatıyorlardı) ve akış boyunca dokunsal geri bildirim
      var (`Haptics`). 96 motor testi + duman testi yeşil, TR/EN doğrulandı.
- [x] **Aşama 7 — katalog 29 → 100 şablon:** 71 yeni şablon, 7 yeni kategori
      (moda, güzellik, spor, emlak, eğitim, müzik, özel günler). Şablonlar artık
      `tools/templates_src/` batch dosyalarından ÜRETİLİYOR; `templatelib.lint`
      hem motor kurallarını hem tasarım hatalarını (kadraj taşması, çakışan
      metin, montajda medyayı örten shape) yakalıyor, `contact-sheet.py` 100
      posteri iki sayfada gözle denetletiyor. Bu hat sayesinde üretim sırasında
      15 şablonu birden bozan sistematik bir hata (montajda sahne zemini medyayı
      örtüyordu) bulunup kalıcı bir lint kuralına dönüştürüldü.
      Uygulama tarafı: galeri "Tümü" görünümünde kategori bölümlerine ayrıldı,
      `ThumbnailStore` sınırsız büyüyen poster önbelleğine LRU sınırı aldı
      (100 poster × ~2 MB bellek baskısıyla uygulamayı kapattırıyordu).
      97 motor testi + duman testi yeşil.

- [x] **Aşama 8 — katalog 127 şablon + sunucu dağıtımı:** zayıf kategoriler
      derinleştirildi (eğitim/emlak/müzik/güzellik/spor/moda artık 8'er şablon);
      hiçbir kategori 6'nın altında değil. Örnek klip üreteci tek kompozisyondan
      **altı kompozisyona** çıktı (manzara, şehir, iç mekân, tepeden tabak,
      portre, kumaş) ve vitrin klibi artık şablonun KATEGORİSİNE göre seçiliyor
      — yemek şablonu tabak, emlak şehir, moda kumaş görseliyle çıkıyor.
      DAĞITIM: posterler artık uygulama paketine tümüyle girmiyor
      (`templates/seed-posters.txt` ile ~28 seed), gerisi CDN'den inip
      önbelleğe alınıyor; paket **26 MB → 18 MB** ve katalog büyüdükçe
      artmıyor. CDN adresi `Info.plist` → `TemplateCDNBaseURL` ile
      yapılandırılıyor (eskiden yalnız `--cdn` bayrağıyla açılabiliyordu, yani
      yayınlanan uygulama ağa hiç çıkmıyordu). `tools/publish-cdn.sh` yükleme
      ağacını hazırlayıp tutarlılığı doğruluyor; ayrıntı `docs/cdn-deployment.md`.

- [x] **Aşama 9 — hareket tasarımı (slayt hissini kırma):** katalog ölçüldü ve
      sorun sayısallaştırıldı — şablonların %82'si tek sahneli, animasyonların
      %38'i `fadeIn`, kesme yoğunluğu 0,21 sahne/sn (modern reel ~0,7–1,5) ve
      müzik `bpm`'i render katmanına HİÇ ulaşmıyor. Motora altı yeni preset
      eklendi: `kineticWords` (kelime kelime giriş — `TextRasterizer.layout`
      ile tek yerleşimden kelime geometrisi), `punchIn`, `spinIn`, `swingIn`,
      `floatLoop`, `shake`. Katalogun tamamı `templatelib.enliven()` ile tek
      geçişte zenginleştirildi (203 yeni animasyon: 62 kelime kelime başlık,
      77 süzülen katman, 55 titreşen rozet); lint artık motorun tanımadığı
      preset adını da yakalıyor. EDİTÖRE RENK PANELİ: motorun zaten desteklediği
      `paletteOverride` arayüze bağlandı — tek dokunuşla şablonun tüm vurguları
      (rozet, fiyat, çizgi, buton) birlikte değişiyor. 97 test + duman testi yeşil.

- [x] **Aşama 10 — tempo hizalama + gerçek vitrin medyası (ikisi de bedava):**
      `TemplateTempo` videonun süresini seçilen parçanın TAM ÖLÇÜSÜNE oturtup
      tüm zamanları aynı oranda ölçekliyor — müzik yarım kesilmiyor, girişler
      vuruşlarla tutarlı hale geliyor. Katalogun 92/127 şablonu hizalanıyor,
      ortalama sapma 0,48 sn (tasarımı bozmayacak kadar küçük); gereken esneme
      %15'i aşarsa şablona DOKUNULMUYOR. 5 test. Sahne sınırlarını tek tek
      vuruşa snap ETMİYORUZ: kademeli girişler ızgaraya çekilince üst üste
      biniyor. MÜZİK: kullanıcının kendi klibinin sesi seçilebiliyor
      (`AudioInput` zaten herhangi bir AVAsset aldığı için motor değişmedi) ve
      sonuç ekranı "şarkıyı Instagram/TikTok'ta ekleyebilirsin" diyor —
      popüler şarkı lisansı platformun, üçüncü parti editörün değil.
      MEDYA: `tools/fetch-sample-photos.py` yalnız CC0/kamu malı görselleri
      künyesiyle indiriyor (`tools/samples/source/CREDITS.md`), üreteç bunları
      Ken Burns'lü kliplere çeviriyor ve klip seçimi artık dosya ADINDAN
      okunuyor (indeks tabanlıyken gerçek foto eklenince kayıyordu).

- [x] **Aşama 11 — gerçek medyayla vitrin denetimi (üç gerçek hata):** gerçek
      fotoğraflarla üretilen 127 posteri göz kontrolünden geçirmek üç hatayı
      birden ortaya çıkardı; hepsi düzeltildi ve ikisi teste bağlandı.
      1. **METİN YERLEŞİMİ (60 şablonu etkiliyordu):** `CTFrameGetLineOrigins`
         satır origin'lerini çerçeve YOLUNA GÖRE veriyor; metin kutuda dikey
         ortalandığı için yolun kendi origin'i eklenmezse hem satır vurgusu
         (`highlightColorRole`) metnin altına kayıyor hem de `kineticWords`
         kelimeleri yanlış banttan kırpılıp "glifin yarısı kesilmiş" görünüyordu
         (52 kineticWords + 8 vurgulu şablon). `TextRasterizer` artık
         `drawRect` origin'ini ekliyor; iki regresyon testi (kelime kutusu metnin
         pikselleri üzerinde mi, vurgu bandı ortalanmış mı) düzeltme geri
         alınınca kırmızıya dönüyor — doğrulandı.
      2. **VİTRİN MEDYASI KÜRATÖRLÜĞÜ:** indirilen CC0 karelerden biri (Commons
         "suckling pig") sağ altta **cihaz filigranı + tarih damgası** ve üstte
         tanınabilir el taşıyordu; 6 posterde görünüyordu. Lisans serbest olsa da
         vitrine giremez. Kaldırıldı; kalıcı çözüm `tools/samples/source/
         REJECTED.txt` — elenen Commons başlıkları orada, `fetch-sample-photos.py`
         onları bir daha indirmiyor ve künyeye "elendi" olarak yazıyor (dosyayı
         elle silmek yetmiyordu, sonraki koşu geri indiriyordu).
      3. **ÖKSÜZ KLİP:** `--make-samples` eski `sample-*.mp4`leri silmiyordu;
         `source/`ten bir fotoğraf çıkınca numaralar kayıyor, eski dosya klasörde
         kalıyor ve MediaPool onu yine vitrine koyuyordu (elenen fotoğraf
         posterlerde yaşamaya devam etti). Üreteç artık klasörü temizliyor.
      Ayrıca kategori→klip eşlemesi düzeltildi: `promo` artık nötr zemin
      (kumaş/stüdyo) istiyor — "Keten Gömlek ₺1.290" kartı bir tabak etle
      çıkıyordu; `beauty` örgü dokusu yerine stüdyo/kafe alıyor; YAKIN PLAN
      dokular (kumaş/örgü/deri) yedek listesinin sonuna alındı ve kaydırma
      yalnız ana bölümde yapılıyor — katalogun İLK kartı tam kadraj örgü
      dokusuyla çıkmış ve başlık okunmaz olmuştu.
      Gerçek fotoğraf havuzu 15 indirmeden 5 kareye budandı (`--per 3`):
      elenenler tablolar (Commons "mountain landscape sunset" araması önce
      TABLO getiriyor — sorguya `-painting -oil` eklendi), tanınabilir insanlı
      kafe kareleri, başka markanın kampanya afişi ve cihaz filigranlı kareler.
      `--inject-media` artık isteğe bağlı bir DOSYA YOLU alıyor: duman testi
      gerçek fotoğrafla koşabiliyor (eskiden hep sentetik gradyan enjekte
      ediyordu, yani "gerçek foto" yolu hiç görülmüyordu). 104 test + duman
      testi yeşil; simulator'da gerçek fotoğrafla editör → export doğrulandı.
      NOT: 127 posterin/önizlemenin İÇERİĞİ değişti ama manifest `version`
      artırılmadı — CDN adresi (`TemplateCDNBaseURL`) hâlâ boş, yani hiçbir
      yerde önbellek yok. İlk yayından SONRA varlıkları yeniden üretirsen
      `version` artırmak ZORUNLU (cache anahtarı `id-vN`).

## Mağazaya çıkış (App Store hazırlığı)

Yayın için yapılanlar:

- [x] **Örnek klipler telifsiz:** `tools/samples/*.mp4` artık `templatekit-assets
      --make-samples` ile ÜRETİLİYOR (soyut manzara: gökyüzü gradyanı, ışık,
      silüet katmanları, bokeh — insan/marka/gerçek yer yok). Kaynağı belirsiz
      görüntüler depodan kaldırıldı; klipler uygulama paketine GİRMİYOR, yalnız
      vitrin varlıklarını (`thumbs/`, `previews/`) üretiyorlar.
- [x] **Editör boş açılıyor, medyasız export kilitli.** Kullanıcının videosuna
      bizim örnek görüntümüz asla girmez; slotlar kesikli çerçeveyle "ekle"
      çağrısı yapar, ilk medya seçilince önizleme kendiliğinden render edilir.
- [x] **Paywall yasal gereklilikleri** (Guideline 3.1.2): süre/fiyat/otomatik
      yenileme cümlesi + Kullanım Koşulları ve Gizlilik Politikası bağlantıları
      (`Legal.swift`, ayarlarda da var). Ürünler gelmeden fiyat UYDURULMAZ.
- [x] **`PrivacyInfo.xcprivacy`**: izleme yok, toplanan veri yok, required-reason
      API'leri (UserDefaults / dosya zaman damgası / boş disk) gerekçeleriyle.
- [x] **Release temizliği:** demo bayrakları (`--pro`/`--free`) yalnız DEBUG
      derlemede çalışır, `ITSAppUsesNonExemptEncryption=false`, filigran yazısı
      tek yerden (`AppInfo.displayName`).
- [x] **TR + EN lokalizasyon:** arayüz `Localizable.xcstrings` (kaynak dil TR),
      içerik (şablon adları, kategori, müzik, şablonların varsayılan metinleri)
      `LocalizedText` üzerinden cihazın diliyle çözülür (`AppLanguage`). Galeri
      POSTERLERİ de dile bağlı: `thumbs/<id>.jpg` (tr) + `thumbs/en/<id>.jpg`
      (`templatekit-assets --lang en`), katalog önce dilin klasörüne bakar.
      Şablon id'sine göre elle yazılmış Türkçe demo metin tablosu kaldırıldı.
- [x] **Export dayanıklılığı:** iptal düğmesi, arka plan görevi (uygulamadan
      çıkınca render ölmüyor), export öncesi boş alan kontrolü ve ham `Error`
      dökümü yerine anlaşılır mesajlar (`ExportMessage`).
- [x] **Fotoğraflar'a kaydet** (`PhotoSaver`, yalnız EKLEME izni), boş/hata
      ekranları (galeri + Videolarım), depolama boyutu gösterimi.
- [x] **Erişilebilirlik:** oynatıcı kontrolleri ve scrub çubuğu VoiceOver ile
      kullanılabilir (ayarlanabilir öğe), medya slotları ve galeri kartları
      anlamlı etiketli.
- [x] **Duman testi:** `App/Scripts/smoke.sh` — galeri → editör → medya →
      export → Videolarım → paywall → EN dili, çökme raporu kontrolüyle.
- [x] **StoreKit test yapılandırması:** `App/StoryTemplate.storekit` (iki ürün,
      3 gün deneme) şemaya bağlı. DİKKAT: bu yapılandırma yalnız **Xcode'dan**
      çalıştırınca devreye girer; `simctl launch` ile başlatılan uygulamada
      ürünler boş gelir (paywall "Fiyatlar yükleniyor…" gösterir).

Yayın öncesi KALAN (kod dışı ya da cihaz/hesap gerektiren):

- [ ] **Uygulama adı + ikon.** Şu an `AppInfo.displayName = "StoryTemplate"`
      (filigran, `CFBundleDisplayName` ve ikon bu adla).
- [ ] **Gizlilik politikası + destek sayfası** yayınlanacak; `Legal.swift`
      içindeki iki URL gerçek adresle değişecek (App Store Connect zorunlu alan).
- [ ] **App Store Connect:** abonelik grubu + `com.storytemplate.pro.monthly` /
      `.yearly` ürünleri, fiyatlar, deneme, lokalize açıklamalar. Sonra
      `BillingBackend.resolved` varsayılanı `.storeKit` yapılacak.
- [ ] **Gerçek cihazda export smoke testi** (montajın 2. geçişi simulator'da
      çöküyor) + bellek/ısınma profili.
- [ ] **Crash reporting + analitik sağlayıcısı** seçimi (bir `AnalyticsSink`
      adaptörü); seçildiğinde `PrivacyInfo.xcprivacy` ve App Store Connect
      gizlilik formu birlikte güncellenecek.
- [ ] **Posterlerin/önizlemelerin gerçek CDN'e yüklenmesi** (https) ve
      `--cdn` varsayılanının ürün adresine bağlanması.
- [ ] **XCUITest hedefi** (duman testi şimdilik betikle koşuyor), mağaza
      vitrini: ekran görüntüleri, açıklama, anahtar kelimeler, TestFlight turu.

Bilinen kısıtlar: klasik (sahnesiz) şablonda ≤1 video slotu; montaj sahnesinde
≤4 eşzamanlı video (performans); `maxLines` sert sınır değil (auto-shrink sığdırır);
klasik yolda VİDEO slotuna filtre uygulanmaz (CoreAnimationTool sınırı — foto ve
montaj medyasında çalışır); simulator'da montaj önizlemesinde müzik export'a
gömülü değil, ayrıca çalınır (1. geçiş videosunun ses track'i yok); lottie
`colorRemap` düz dolgu/çizgi renklerini değiştirir, GRADYANLI varlıkta çalışmaz
(gradyan durakları renk+konumu iç içe yazar — yanlış eşleşme animasyonu bozar);
lottie varlıkları şu an yalnız uygulama paketiyle gelir, CDN'den şablonla
birlikte inmez (paket/zip biçimi henüz yok).
