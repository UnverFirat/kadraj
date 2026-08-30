# Kadraj — durum özeti

**Tarih:** 2026-08-27 · **Sürüm:** 1.0 (1) · **Dal:** `main` · **Test:** 151 yeşil

Tek sayfalık genel bakış. Ayrıntı ve gerekçeler `YAPILACAKLAR.md`'de; bu dosya
"nerede duruyoruz, sırada ne var" sorusunu üç dakikada cevaplamak için.

| | |
|---|---|
| Katalog | 127 şablon · 14 kategori · 70 ücretsiz / 57 Pro |
| Diller | TR + EN, ikisi de eksiksiz (arayüz, şablon içeriği, poster, mağaza metni) |
| Vitrin | 55 kamu malı/CC0 fotoğraf → 65 örnek klip → 254 poster + 254 önizleme |
| Cihaz | iPhone 14 Pro (iOS 26.6) üzerinde kurulu ve çalışıyor |
| Yayına engel | Cihaz turu tamamlanmadı · App Store Connect kaydı yok · Pages kapalı |

---

## Yapıldı

### Vitrin gerçek fotoğraflara geçti
`tools/samples/source/` **5 → 55 fotoğraf**, hepsi kamu malı / CC0, künyeleri
`source/CREDITS.md`'de. Hat zaten kuruluydu; eksik olan **gözle eleme turuydu** —
133 aday indirilmiş ama `ACCEPTED.txt` hiç yazılmamıştı, o yüzden 127 şablon beş
kareyi paylaşıyordu ve katalog sentetik çizimlerle doluydu.

78 kare elendi (gerekçeleriyle `source/REJECTED.txt`'te; betik bir daha indirmez):
tanınabilir yüz, okunur marka (Nike, Coca-Cola, Clinique, Sony, acer), müze
etiketi, kartvizit, tarihî sepya tarama, tablo/gravür, patent çizimi, uydu
görüntüsü.

`MediaPool` eşleştirmesine dokunulmadan düzelenler: tırnak sanatı (gezegen
çizimi → makyaj paleti), saç rengi (tabak → palet), spor salonu (sokak → dambıl),
spa (boş gradyan → fırçalar), emlak (tek sokak karesi → ev cepheleri + iç mekân),
kahve molası (tabak çizimi → hamur yoğuran eller). Eşleştirme zaten doğruydu,
eşleşecek fotoğraf yoktu.

### Arayüz: kullanıcı turu bulguları

| Kusur | Sonuç |
|---|---|
| Metin alanları "Metin N" görünüyordu | 418/746 (%56), 92 şablon → **0/746** |
| Arama sıfır sonuç veriyordu | 18/54 sorgu → **0/62** |
| Videolarım ızgarası ekran dışına taşıyordu | düzeldi |
| Klip kadraj çerçevesi kadrajı yanlış gösteriyordu | düzeldi |
| Paywall ilk karede güven satırı kesikti | düzeldi |
| 4:5 / 1:1 yalnız üretiyordu, paylaşım 9:16 kalıyordu | oran seçici oldu |
| Yazı tabanlı 17 şablon sürenin %15'inde donuyordu | tasarımın tamamı |
| Metin sekmesinde aynı anda 2 alan görünüyordu | ~4 alan |
| Taslak yalnız medya varsa kaydediliyordu | metin + renk + müzik de |
| Galeri durum çubuğu altından geçiyordu, rozet başlığı örtüyordu | perde eklendi |

### Cihaz turunun getirdikleri
İlk kez gerçek telefona kurulunca çıkanlar — hiçbiri simulator'da görünmüyordu:

- **Oynatıcı sızıntısı.** Döngü gözlemcisi oynatıcıyı güçlü tutuyordu; her
  yenilemede eskisi serbest kalmıyor, arkada çalmaya devam ediyordu. Üç şikâyeti
  birden açıklıyordu: ses duplikasyonu, "müziği kapattım kapanmıyor", ısınma.
- **Otomatik önizleme geri alındı.** Bilinçli bir tasarım kararının tersi:
  simulator'da akıcı hissettiriyordu, cihazda kullanıcı istemeden video+ses
  başlatmak ve her fotoğrafta bir render kuyruğa atmak demekti. Artık render'ı
  kullanıcı başlatıyor ("Önizle" / "Önizlemeyi yenile").
- **Editörden çıkarken çökme — bulundu, üretildi, düzeltildi.** Sebep bellek
  baskısı değildi: `PlayerScrubView` zaman gözlemcisinin token'ını tutuyor ama
  hangi oynatıcıdan aldığını tutmuyordu; önizleme yenilenince token yanlış
  oynatıcıya veriliyor ve `removeTimeObserver` istisna atıyordu. Adımlar bilinince
  simulator'da her seferinde üretilebiliyor.
- **Akıcılık / bellek turu.** Haptik üreteçleri uzun ömürlü yapıldı (57 çağrı
  yeri), etiket tablosu önbelleğe alındı (tuş başına 303 `String(localized:)`),
  arama normalizasyonu yüklemeye alındı, fotoğraflar tam çözünürlükte açılmıyor
  (48 MP → ~195 MB riski), montaj render'ının 1. geçişi artık iptal edilebiliyor,
  taslak yazımı ana iş parçacığından çıktı, önizleme arka planda duraklıyor.
- **Cihaza kurulum yolu.** `DEVELOPMENT_TEAM` projeye yazıldı,
  `App/Scripts/install-device.sh` eklendi (Release kurulumu dahil).

### Katalog sırası kişisel kullanıma göre dizildi
`tools/audience-split.py` ölçtü: **62 işletme / 41 kişisel / 24 nötr**. Asıl
sorun sayı değil sıraydı — Kutlama ve Özel Günler bölümleri 14 bölümün 12. ve
13. sırasındaydı. Sıra üç kuşağa göre yeniden dizildi (kişisel → karma →
işletme). Kişisel şablonların ilk yarıdaki payı 21/41 → **33/41**, ortanca sıra
62. karttan **35.** karta indi. İşletme şablonları silinmedi, sona alındı.

---

## Kalan

### 1. Cihazda doğrulama (yayına engel)
Uygulama telefonda kurulu; aşağıdakiler elle gezilmeyi bekliyor.
Kurulum: `./App/Scripts/install-device.sh`

- [ ] **A** Medya ekle → video ve ses **başlamamalı** *(simulator'da geçti; ses hiç duyulmadı)*
- [ ] **B** "Önizle" → tek render; değişiklikte "Önizlemeyi yenile" çıkmalı *(simulator'da geçti)*
- [ ] **C** 5 fotoğrafı tek tek ekle, birkaç kez önizle → **ses üst üste binmemeli**
- [ ] **D** Müziği "Müziksiz" yap → ses **anında** kesilmeli
- [ ] **E** Editörden geri çık → çökmemeli *(düzeltildi, cihazda teyit bekliyor)*
- [ ] **F** Isınma / akıcılık: 5 klipli montajda gezinirken
- [ ] **G** **Montaj export'unun metinli çıktısı** — katalogun %62'sinde bu yol hiç görülmedi

`G` en kritiği: simulator'da montaj çıktısı metinsiz geliyor (belgeli bir
simulator kısıtı), yani 79 şablonun gerçek çıktısını henüz kimse görmedi.
Ayrıca cihazda görülmemiş olanlar: montaj + hız + trim birlikte, ritim
dönüşümü uygulanmış 50 şablon, 4:5 / 1:1 yeniden kadrajlama.

### 2. Sende olan işler (hesap / para / karar)
- **App Store Connect kaydı** — uygulama ve abonelik ürünleri oluşturulacak.
  Sonrası tek satır: `BillingBackend.resolved` varsayılanı `.storeKit`.
  Şu an paywall'daki ₺399,99 / ₺79,99 koda gömülü sahte fiyatlar.
- **GitHub Pages açılması** — `docs/` altındaki gizlilik/koşullar/destek
  sayfaları 404 veriyor. Settings → Pages → `main` / `/docs`.
- **CDN'e yükleme** — `tools/publish-cdn.sh` ağacı üretiyor; adres ve yükleme
  sende. (Galeri CDN olmadan da eksiksiz; CDN yalnız önizleme videoları ve
  yayın sonrası yeni şablonlar için.)
- **Crash reporting / analitik sağlayıcı seçimi** — seçilince adaptör yazılır.
- **Müzik lisansı** — karar verildi: alınmayacak. 21 sentez parça altlık olarak
  kalıyor, kullanıcı şarkıyı Instagram/TikTok'ta kendi ekliyor.

### 3. Bilinen kod borcu (dokunulmadı)
- `EditorView` tek parça (~1750 satır, ~25 `@State`) — tek state değişimi body
  başına 40+ katman taraması tetikliyor.
- Kırpma/zoom sürüklemesi kare başına tüm `EditorView` gövdesini kuruyor.
- `ExportLibrary.add` ana iş parçacığında video kopyalıyor + poster decode ediyor.
- `MyVideosView` kart gövdesinde senkron `UIImage(contentsOfFile:)`.
- `tmp` altındaki `preview-*` / `export-*` / `picked-*` artıkları toplanmıyor.
- XCUITest hedefi yok (duman testi `App/Scripts/smoke.sh` ile bayrak tabanlı).

### 4. Vitrinde zayıf kalanlar
`pet`, `nails`, `salon`, `vinyl`, `yoga` türlerinde CC0 havuzu gerçekten dar —
üç indirme turu denendi, adayların hepsi ya tarihî ya tanınabilir kişi/mekân.
Bu şablonlar yedek görsele düşüyor (`pet-star-01` bir kedi şablonu ama tiramisu
gösteriyor). Çözüm lisanslı kaynak ya da o şablonların yeniden tasarlanması —
daha fazla Commons sorgusu değil.

Kişisel şablon **eklemek** de açık bir seçenek: sıra ucuzdu ve önce o denendi,
sayı dengesi (41 kişisel / 62 işletme) değişmedi.

---

## Nerede ne var

| Dosya | İçerik |
|---|---|
| `YAPILACAKLAR.md` | Açık işler, gerekçeler, ölçümler — **asıl çalışma dosyası** |
| `README.md` | Mimari, aşama aşama geliştirme günlüğü |
| `MAGAZA.md` | App Store Connect'in istediği her metin |
| `KULLANICI-ANALIZI.md` | "Kullanıcı neden para verir" değerlendirmesi |
| `docs/template-format.md` | Şablon JSON sözleşmesi |
| `docs/render-engine.md` | Motor |
| `docs/cdn-deployment.md` | CDN dağıtımı |
| `tools/samples/source/CREDITS.md` | Vitrin fotoğraflarının lisans künyesi |

**Yararlı komutlar**

```bash
./App/build.sh                      # simulator: derle + kur + başlat
./App/Scripts/install-device.sh     # gerçek iPhone: derle + kur + başlat
./App/Scripts/smoke.sh              # huni duman testi (galeri → export → Videolarım)
python3 tools/contact-sheet.py      # 127 posteri 4 sayfada gözden geçir
python3 tools/audience-split.py     # kişisel/işletme dağılımı
cd TemplateKit && swift test        # 151 test
```
