# Kadraj — yapılacaklar

2026-08-16. Üç tur iş yapıldı: (1) uçtan uca testin kod tarafındaki bulguları,
(2) "kullanıcı neden para verir" değerlendirmesinden çıkan kontrol + ritim
işleri, (3) `KULLANICI-ANALIZI.md` planının P1-yarısı + P2 + P3 + P4-kod
tarafı. Üçü de **Bitti** bölümlerinde; kalanlar aşağıda.

**Şu an açık olan üç şey** (sırayla):

1. **P0 — cihaz doğrulaması.** Katalogun %62'si (79 şablon) gerçek cihazda hiç
   denenmedi. Fiziksel iPhone gerekiyor; bu yapılmadan yayın yok (§4.1).
2. **Gerçek fotoğraf havuzu.** Siluet gitti ama yerine gelen sade gradyan
   "senin fotoğrafın buraya gelecek" demiyor. Yüzsüz-ama-gerçek kareler
   (arkadan baş, omuz üstü, çalışan eller) bu işi bitirir — **lisans/model
   izni kararı sende**.
3. **Mağaza kaydı ve marka artıkları:** bundle id, ürün ID'leri, ikon,
   GitHub Pages (§5).

---

## 0. Dil / global hazırlık — 2026-08-19

Uygulama iki dilli ve **İngilizce tarafı eksiksiz**: arayüz 239/239 anahtar,
şablon içeriği 873/873 alan, 21/21 müzik parçası, iki dilde ayrı poster ve
önizleme seti, `MAGAZA.md`'de İngilizce mağaza metni.

Bu turda düzeltilen iki şey:

1. **Yedek dil hatası (ciddiydi).** `CFBundleDevelopmentRegion` `tr` olduğu
   için cihazın dili pakette yoksa iOS Türkçe'ye düşüyordu — Almanca,
   Fransızca, Japonca bir kullanıcı uygulamayı BAŞTAN SONA Türkçe görüyordu
   (simulator'da `-AppleLanguages "(de)"` ile doğrulandı). `en` yapıldı;
   Türkçe cihazlar eşleşmeyle tr'yi almaya devam ediyor, regresyon yok.
2. **İngilizce demoda Türkçe sızıntısı.** ₺ fiyatlar, Türk isimleri ve yer
   adları İngilizce posterlerde görünüyordu; 73 alan temizlendi (Türkçe taraf
   hiç değişmedi). Kalıcı ders: düzenli ifade taraması YETMİYOR — Türkçe
   harfleri silinmiş ("Sapanca · Golkoy") ya da küçük harfli ("@mertkaya.music")
   olanlar ancak 127 posterin tamamına gözle bakınca çıktı.

Yasal sayfalar hakkında bir DÜZELTME: "yalnız Türkçe" sanılıyordu, değil —
`docs/{gizlilik,kosullar,destek}.html` üçü de TEK dosyada iki dilli (Türkçe,
sonra `<hr id="english">`, sonra İngilizce tam metin). Kopya `docs/en/`
açılmadı: hukuk metnini çoğaltmak iki sürümün zamanla ayrışması demek.
Bunun yerine üstte "English ↓" bağlantısı ve `#english` çapası eklendi;
`Legal.swift` Türkçe olmayan cihazda URL'i çapayla açıyor.

**Kalan dil işi yok.** (Üçüncü bir dil eklenecekse: `Localizable.xcstrings`'e
dil eklemek + şablonlardaki `LocalizedText`lere anahtar eklemek + o dil için
poster/önizleme üretmek gerekir — üçü birden.)

---

## 1. Katalog ritmi — BİTTİ (borç 9, hepsi tasarım kararı)

| Ölçüt | Önce | Şimdi |
|---|---|---|
| Eşiği (0,4 kesme/sn) geçen şablon | 14 | **63 / 72** |
| Ortalama kesme yoğunluğu | 0,23 | **0,64** |
| Borç | 96 | **9** |

50 şablon çevrildi (38 üretim hattından, 12 elle yazılmış JSON'dan
`tools/rhythmize-json.py` ile). Kalan **9** şablon elle tasarlanmış çok
sahnelilerdir — `beauty-before-after-01`, `dessert-reveal-01`,
`split-screen-01`, `reel-collage-01`, `engagement-01`, `anniversary-01`,
`studio-session-01`, `last-chance-01`, `restock-01`. Bunlarda sahne sayısı bir
TASARIM kararı: "öncesi/sonrası"nı ikiye bölmek şablonun fikrini bozar. Daha
fazla kesme istenirse elle yeniden tasarlanmalı, otomatik dönüşümle değil.

`build-templates.py --check` borcu ölçmeye devam ediyor
(`RHYTHM_DEBT_BUDGET = 9`): yeni durağan bir şablon eklenirse lint düşer.

**Ölçütün sınırı:** medya kadrajın en az %35'ini kaplamayan şablonlar (alıntı
kartı, fiyat listesi, 4'lü kolaj kartı — 23 tane) ne dönüştürülüyor ne de borç
sayılıyor. O tasarımlarda hareket metin animasyonundan gelir; köşedeki küçük
fotoğrafı 1,5 saniyede bir kesmek ritim değil titreme üretir.

---

## 2. Müzik — KARAR VERİLDİ: lisans alınmayacak

**Popüler şarkı lisansı ALINMAYACAK.** Kullanıcı videoyu Instagram/TikTok'a
yükledikten sonra şarkıyı orada kendisi ekleyecek — o lisans platformun ve
zaten yalnız orada geçerli; üçüncü parti bir editörün veremeyeceği şey.

Bunun sonucu olarak:
- Kütüphanedeki 21 parça (`AudioSynth` ile sentez) bir **altlık** olarak kalır:
  telif riski sıfır, sessiz video paylaşmak zorunda kalan kullanıcıyı kurtarır.
- Kullanıcının KENDİ klibinin sesi seçilebiliyor (müziğin yerine geçer).
- Sonuç ekranındaki "istediğin şarkıyı Instagram/TikTok'a yükledikten sonra
  ekleyebilirsin" satırı bu kararın kullanıcıya söylenmesidir — kaldırılmamalı.

Bu madde artık bir iş değil, bir karar kaydı.

---

## 3. Vitrin varlıkları — YENİDEN ÜRETİLDİ (2026-08-16)

254 poster + 254 önizleme bir kez daha baştan üretildi: `.portrait` silueti
kaldırıldığı ve metin okunabilirliği hapları eklendiği için eski varlıklar
kodla tutarsız kalmıştı.

**Sıra tuzağı (bir kez düşüldü, tekrarlanmasın):** poster üretimi
`SampleClips.swift`'ten değil, `tools/samples/*.mp4` dosyalarından besleniyor.
Kodu düzeltip doğrudan poster üretirsen eski kliplerden üretmiş olursun —
siluet ilk turda tam bu yüzden posterlerde kaldı. Doğru sıra:

```
kod → --make-samples → poster/önizleme üretimi → tools/contact-sheet.py ile gözle bak
```

Manifest `version`'ları bilinçli artırılmadı (77×v1, 50×v2): CDN henüz
yayınlanmadı, ortada önbellek yok. **İlk yayından sonraki** her yeniden
üretimde artırılmalı.

---

## 3b. Vitrin varlıkları — önceki tur (2026-08-12)

Ritim dönüşümünden sonra 254 poster ve 254 önizleme videosu iki dilde
baştan üretildi (`templatekit-assets`, 127 şablon × 2 dil, 171 sn/dil, hata
yok). Artık vitrin katalogun güncel halini gösteriyor: dönüşen şablonların
önizlemesinde kesmeler görünüyor, overlay sabit kalıyor.

| Varlık | Boyut | Nerede |
|---|---|---|
| `thumbs/` (254 poster) | 12,3 MB | uygulama paketi + CDN |
| `previews/` (254 video) | 140 MB | YALNIZ CDN (git'te izlenmiyor) |

Varlıklar YENİDEN üretilirse (yayından sonra) manifest'teki ilgili girdilerin
`version`'ı artırılmalı — cache anahtarı `id-vN`. Şu an ilk yayın öncesi
olduğumuz için hiçbir yerde önbellek yok; ritim dönüşümüyle içeriği değişen
50 şablon `version: 2`, geri kalanı `version: 1`.

---

## 4. Doğrulama borcu

### 4.1 Cihazda hiç denenmedi
Simulator'da montaj export'u metinsiz/filigransız çıkıyor — bu **kodda belgeli
bir simulator kısıtı** ([ExportFlow.swift:164](App/StoryTemplate/ExportFlow.swift:164)),
hata değil; önizlemede metin canlı bindiriliyor (`MontagePreviewOverlay`).
Cihazda doğrulanmayanlar:

- montaj + klip hızı + trim birlikte,
- ritim dönüşümü uygulanmış 50 şablonun görünümü,
- 4:5 / 1:1 yeniden kadrajlama (macOS'ta testli, cihazda değil),
- bellek/ısınma profili (montaj + otomatik önizleme yenileme birlikte).

### 4.2 XCUITest hedefi
Duman testi `smoke.sh` (gerçek video klibiyle montaj export'u dahil, cihazı
açıkça seçiyor). UI testleri bir hedefe bağlanabilir — özellikle taslak
geri yükleme ve klip ayarları ekranı gibi çok adımlı akışlar.

---

## 5. Bunları ben yapamam (hesap/cihaz/para gerekiyor)

- **Ödeme canlıya alma.** Fatura arka ucu varsayılan `local`; paywall'daki
  ₺399,99 / ₺79,99 [Entitlements.swift:139](TemplateKit/Sources/TemplateKit/Billing/Entitlements.swift:139)
  içinde koda gömülü sahte fiyatlar, "Ücretsiz denemeyi başlat" gerçek satın alma
  yapmıyor. App Store Connect'te abonelik ürünleri tanımlanmalı; sonra
  `BillingBackend.resolved` varsayılanını `.storeKit` yapmak **benim** işim (tek satır).
- **ASC kaydı.** Ad işi bitti (filigran, `CFBundleDisplayName`,
  `AppInfo.displayName`, deep link `kadraj://` → hepsi Kadraj). Bundle id
  **`com.fireflysoftware.kadraj`** olarak karara bağlandı ve kodda uygulandı
  (2026-08-18) — diğer üç uygulamayla aynı yayıncı öneki; ürün ID'leri
  `…kadraj.pro.{monthly,yearly}`. İkon da var (1024×1024, commit'li).
  Kalan: ASC'de uygulamayı ve abonelik ürünlerini OLUŞTURMAK — sende.
- **Gizlilik/destek sayfaları.** GitHub Pages **hâlâ kapalı** — 2026-08-16'da
  `kosullar/gizlilik/destek.html` üçü de 404 döndü. Depo (`UnverFirat/kadraj`)
  ve `docs/*.html` yerinde; eksik olan deponun Pages ayarı: Settings → Pages →
  Source: `main` / `/docs`. Bu bir hesap ayarı, senin yapman gerekiyor.
- **CDN'e yükleme.** `tools/publish-cdn.sh` ağacı üretiyor; yükleme ve
  `TemplateCDNBaseURL` değeri sende. (Galeri artık CDN OLMADAN da eksiksiz
  görünüyor — CDN yalnız önizleme videoları ve yayın sonrası yeni şablonlar için.)
- **Gerçek cihazda export smoke testi** + bellek/ısınma profili.
- **Crash reporting / analitik sağlayıcı seçimi** (seçince `AnalyticsSink`
  adaptörünü ben yazarım).
- **Müzik lisansı** (yukarıda).

---

## Bitti (2026-08-16) — huni, vitrin cilası, marka

Hepsi `KULLANICI-ANALIZI.md` §4 planından; oradaki kutular nasıl doğrulandığıyla
birlikte işaretli. Testler 135 → **151**.

### Huni (P2)

- [x] **İlk video ücretsiz ve filigransız** — bir kerelik hak
      (`hasFirstFreeExport`). Temiz kurulum → filigransız, hak harcanmış →
      filigranlı; ikisi de MP4'ün pikselinde doğrulandı.
- [x] **Paywall sonuç ekranına taşındı**, galerideki Pro bandı ilk export'a
      kadar gizli.
- [x] **Ücretsiz/Pro dengesi 70 / 57**, her kategori ≥ %50
      (Sosyal 6/21 → 11/21, İş 2/7 → 4/7).
- [x] **Karşılama:** 3 kare, her karede atlanabilir. "İlk videon filigransız"
      rozeti yalnız hak duruyorsa çıkıyor. `smoke.sh`'ın iki bayraksız
      başlatmasına `--skip-onboarding` eklendi — otomasyon karşılamaya
      takılmıyor.
- [x] Çeviri kataloğuna 9 metin (243 → **252**). Biri var olan bir açıktı:
      `ExportResultView` "İlk videon filigransız" metnini kullanıyordu ama
      katalogda yoktu — İngilizce'de Türkçe düşüyordu.

### Vitrin ve render cilası (P1-yarısı, P3)

- [x] **`.portrait` silueti kalktı** — yumuşak plato fonu + cyclorama kavisi.
- [x] **Metin okunabilirliği hapları** — yalnız medyayı ≥ %85 kapsayan metne,
      emoji sticker hariç. Kök neden ilginç: kesişim testi `> 0` olduğu için
      2,8e-17 birimlik kayan nokta artığı "medya üstünde" sayılıyordu;
      posterdeki sol/sağ asimetrinin sebebi buydu. 15 regresyon testi gerçek
      şablonlara **katman adıyla** kilitli.
- [x] **Rozet/metin zamanlaması** — plaka etiketiyle birlikte giriyor;
      136 çiftin 135'i düzeldi. (Analizde "~2 sn" yazmıştım, kare kare ölçüm
      0,15–0,2 sn dedi — sorun gerçek, tahminim yanlıştı.)
- [x] 254 poster + 254 önizleme yeniden üretildi, kontak baskısıyla tarandı (§3).

### Marka (P4 kod tarafı)

- [x] `CFBundleDisplayName` + `AppInfo.displayName` → **Kadraj**
- [x] Filigran → **"Made with Kadraj"** (export pikselinde teyitli)
- [x] Deep link → `kadraj://`

**Bu turda öğrenilen iki şey:** (1) poster üretimi koddan değil örnek
kliplerden besleniyor — araya `--make-samples` girmezse düzeltme vitrine
yansımıyor. (2) "Testler geçiyor" bu iş kolunda yetmiyor: metin hapı
regresyonu zaten geçen testlerle üretildi, gözle poster bakmadan yakalanmadı.

---

## Bitti (2026-08-12)

Ayrıntılı gerekçeler README "Aşama 12" ve "Aşama 13" bölümlerinde.

### Kontrol: kullanıcı kendi videosuna söz sahibi (Aşama 13)

- [x] **Trim** — klibin hangi saniyesinden başlanacağı, şerit üzerinde
      kullanılacak bölümün penceresiyle. Motor alanı okuyordu, arayüz yoktu.
- [x] **Kadraj** — sürükle/yakınlaştır, üçler kuralı ızgarası; boşluk çıkmayacak
      şekilde sınırlı. Yön sözleşmesi iki export yolunda ölçüldü ve eşitlendi.
- [x] **Klip hızı** 0,25x–4x (aynı şablonda bazı klipler hızlı, bazıları ağır
      çekim). Videonun süresini değiştirmez.
- [x] **Klip sırası** — geri/ileri al; medyayla birlikte kadraj, başlangıç ve
      hız da taşınır.
- [x] **Metin stili** — boyut, renk, yazı tipi ailesi (şablonun kalınlığı korunur).
- [x] **Taslak kaydetme** — "Devam et" şeridi + "kaldığın yerden devam · sıfırla".
- [x] **Önizleme kendiliğinden yenilenir** — video ekrandan kalkmıyor.
- [x] **Gönderi 4:5 / Kare 1:1** — tasarım bozulmadan yeni kadraj.
- [x] **Katalog ritmi** — 50 şablon çok sahneli; borç 96 → 9 (yukarıda ölçüm).

### Uçtan uca testin bulguları (Aşama 12)

- [x] **Katalog cache'i seed'i eziyordu** (en kritik): manifest `revision`
      taşıyor, yeni olan kazanıyor. 5 regresyon testi.
- [x] **Filigran açık zeminde görünmüyordu:** koyu hap + halo; iki şablonda
      export kırpılarak doğrulandı.
- [x] **"Medya ekle" hapı şablonun başlığını örtüyordu.**
- [x] **Fotoğraf seçici çoklu seçim** (boş slot sayısı kadar, seçim sırasıyla).
- [x] **Sekme başlığı kırpılıyordu** ("Med… 5/5" → "Medya 5/5").
- [x] **Galeri vitrini:** 254 posterin tamamı pakete girdi (12 MB); poster
      yoksa kart şablonun paletinden soyut bir sahne çiziyor.
- [x] **`smoke.sh` yanlış cihaza gidebiliyordu** + gerçek video adımı eklendi.
- [x] **Lint'e ritim mandalı.**
