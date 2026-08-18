# Kadraj — kullanıcı gözüyle inceleme ve plan

2026-08-16. Uygulama simulator'da (iPhone 17 Pro) derlendi, çalıştırıldı ve
uçtan uca kullanıldı: galeri gezildi, paywall açıldı, ücretsiz kullanıcıyla
klasik ve montaj şablonu export edildi, çıkan MP4'ler kare kare incelendi.
Katalogun tamamı kontak baskısıyla gözle tarandı (127 şablon).

Bu dosya **YAPILACAKLAR.md'nin yerine geçmez** — o dosya "ne yapıldı / ne
kaldı" defteri. Bu dosya tek bir soruyu cevaplar: *bir kullanıcı bunu kullanır
ve parasını verir mi?*

> **Güncelleme — 2026-08-16 akşamı.** Aşağıdaki teşhis aynı gün uygulandı.
> P2 (huni), P3 (kalite cilası), P4'ün kod tarafı ve P1'in yarısı bitti;
> her madde §4'te nasıl doğrulandığıyla birlikte işaretli. Teşhis metni
> **olduğu gibi bırakıldı** — o günkü halin kaydı; ne değiştiği bölüm
> başlarındaki `DURUM` satırlarında.
>
> Açık kalanlar: **P0 cihaz doğrulaması** (fiziksel iPhone gerekiyor),
> **gerçek fotoğraf havuzu** (lisans/model izni kararı), bundle id ve ASC.

---

## Kısa cevap

**Kullanır mıydım:** Kısmen. Tipografi ağırlıklı şablonlar (fiyat listesi,
menü, emlak künyesi, ders programı, kalın söz) için **evet** — bunlar gerçekten
tasarımcı işi gibi duruyor ve rakiplerde Türkçesi yok. Fotoğraf ağırlıklı
şablonlar için **bugünkü haliyle hayır**: vitrin bana kendi fotoğrafımı o
şablonda hayal ettirmiyor.

**Satın alır mıydım:** Bugün **hayır**. Ürün kötü olduğu için değil — bana
değerini göstermeden para istediği için. İlk dokunuşumda paywall gördüm,
o ana kadar tek bir video üretmemiştim.

> *Aynı gün akşamı:* huni tarafı düzeldi — ilk video artık ücretsiz ve
> filigransız bitiyor, para bundan **sonra** isteniyor. "Değerini görmeden
> para istiyor" gerekçesi kalktı. Kalan "hayır" gerekçesi tek başına
> **vitrin**: fotoğraf ağırlıklı şablonlar hâlâ gerçek fotoğraf göstermiyor.

**Ama:** buradaki mühendislik kalitesi, benzer fiyat bandındaki uygulamaların
çoğundan yüksek. Sorunların neredeyse hepsi **vitrin ve huni** sorunu, motor
sorunu değil. Bu iyi haber: pahalı kısım bitmiş, ucuz kısım eksik.

---

## 1. Gerçekten güçlü olan taraflar

| | |
|---|---|
| **Motor** | İki export yolu, deterministik varlık üretim hattı, lint + ritim mandalı, gerçek modül sınırı (`import TemplateKit`), testler. Bu ölçekte disiplin nadir. |
| **Gizlilik** | Hesap yok, sunucu yok, üçüncü parti SDK yok, `.xcprivacy` doldurulmuş. "Fotoğrafın telefonundan çıkmaz" pazarlama cümlesi değil, kodun gerçeği. Türkiye'de küçük işletme için bu **satın alma sebebi**. |
| **Paywall dürüstlüğü** | Fiyat mağazadan geliyor, uydurma indirim yüzdesi yok, çıkış yolu sol üstte açık, Guideline 3.1.2 metni yerinde, "10.000 kullanıcı" gibi uydurma sosyal kanıt yok. Ret yemez. |
| **Editör derinliği** | Kadraj, trim, klip hızı, sıra, metin stili, taslak, kendiliğinden yenilenen önizleme, 4:5 / 1:1 yeniden kadraj. Bu kontrol seti çoğu şablon uygulamasında yok. |
| **Türkçe-önce içerik** | Şablonlar çeviri değil, Türk esnafı için yazılmış (kuaför randevu, emlak künyesi, bayram tebriği, iftar vakti). Gerçek bir boşluk. |
| **Tipografi şablonları** | `bold-statement`, `price-list`, `menu-card`, `property-specs`, `class-schedule`, `drinks-list`, `word-of-day` — export'ta kare kare baktım, profesyonel duruyor. |
| **Hız** | 6 sn'lik klasik şablon birkaç saniyede export ediliyor. |

Klasik yolu ücretsiz kullanıcıyla export ettim: metin gömülüyor, filigran koyu
hap + halo ile açık zeminde bile okunuyor. O taraf çalışıyor.

---

## 2. Beni durduran şeyler (hasar sırasına göre)

### 2.1 — EN KRİTİK: Vitrin ürünü satmıyor

> **DURUM: YARISI ÇÖZÜLDÜ.** Siluetler katalogdan tamamen kalktı — `.portrait`
> sahnesi artık yumuşak plato fonu + cyclorama kavisi; 254 poster/önizleme
> yeniden üretildi ve kontak baskısıyla tarandı. **Ama asıl iş duruyor:**
> hâlâ 5 gerçek kare katalog boyunca tekrar ediyor. Yerine gelen sade gradyan
> "burası bozuk" demiyor, "senin fotoğrafın buraya gelecek" de demiyor.
> Yüzsüz-ama-gerçek kareler (§4 P1) hâlâ açık.

254 posterin tamamı **5 gerçek fotoğraftan** üretiliyor
(`tools/samples/source/`: bir kesadilya, iki sokak/şehir karesi, bir örgü
doku, bir süet doku). Geri kalan her şey `SampleClipGenerator` ile **çizilmiş
soyut gradyan** — karikatür dağ, ay, gökdelen siluetleri.

Sonuçları kontak baskısında ve uygulamada net görülüyor:

- **Aynı 5 görsel katalog boyunca tekrar ediyor.** Aynı kesadilya 8 yemek
  şablonunda, aynı akşam sokağı onlarcasında. Katalog 127 şablon değil,
  "5 fotoğrafın 127 dizilişi" gibi görünüyor.
- **İnsan gereken şablonlarda yüzsüz koyu bir siluet var.** `.portrait`
  sahnesi iki elipsten ibaret (omuz + kafa,
  [SampleClips.swift:615](TemplateKit/Sources/TemplateKitAssets/SampleClips.swift:615)).
  Bu tam da satan kategorilere çarpıyor: güzellik, kuaför, makyaj,
  öncesi/sonrası, düğün, mezuniyet, müşteri yorumu, moda deneme kabini.
  Bir güzellik şablonunun kapağında kafasız koyu bir gövde görmek "bu uygulama
  bozuk" ya da "bu ürkütücü" hissi veriyor.
- **Şablon posterinin tek işi** "senin fotoğrafın buraya gelecek" dedirtmek.
  Soyut gradyan bunu yapmıyor; ekran koruyucu gibi duruyor.

Boş editör de galeri posterini gösterdiği için aynı siluet editörde de
karşılıyor.

> Bu, App Store ekran görüntülerinde de aynı sorunu yaratır — yani kullanıcı
> daha indirmeden kaybediliyor.

**Neden böyle olmuş:** `CREDITS.md` kendi kuralını koymuş — "tanınabilir insan
içeren kare vitrine girmez". Bu **hukuken doğru bir refleks** (model izni
olmayan kişi ticari vitrinde kullanılamaz). Ama çözüm siluet çizmek değil.

**Doğru çözüm:** kimliği görünmeyen ama **gerçek** insan varlığı — arkadan
çekilmiş baş, omuz üstü kadraj, saç detayı, çalışan eller (manikür, hamur,
kahve, makas), boyundan aşağısı. Yüz yok, model izni sorunu yok, "gerçek
fotoğraf" hissi var. Bu tek değişiklik güzellik/düğün/moda kategorilerini
kurtarır.

### 2.2 — Paywall değerden önce geliyor

> **DURUM: ÇÖZÜLDÜ.** İlk video ücretsiz ve filigransız (bir kerelik hak,
> `hasFirstFreeExport`); galerideki Pro bandı ilk export'a kadar gizli;
> denge 70 ücretsiz / 57 Pro ve **her kategori ≥ %50** (Sosyal 6/21 → 11/21,
> İş 2/7 → 4/7). Temiz kurulumda uçtan uca doğrulandı.

- 127 şablonun **64'ü kilitli**. Kategori bazında daha sert:
  Sosyal **6/21** ücretsiz, İş **2/7**, Kutlama **3/6**.
- Galeride, daha tek şablon görmeden, arama kutusunun hemen altında
  "Pro'ya geç" bandı duruyor.
- Ben uygulamayı açtım, ilgimi çeken ilk şablona dokundum, **paywall açıldı**.
  O ana kadar hiçbir şey üretmemiştim. Bu noktada normal kullanıcı çıkar.

Şablon uygulamalarında dönüşüm şurada olur: kullanıcı **bir kere** videoyu
bitirir, sonucu beğenir, filigranı görür, *"şunu kaldırayım"* der. Kadraj bu
anı yaşatmadan ödeme istiyor.

### 2.3 — Kullanıcının fotoğrafı metni okunmaz yapabiliyor

> **DURUM: ÇÖZÜLDÜ.** Metin katmanları filigranın aldığı korumanın aynısını
> alıyor. Kural dar tutuldu: hap yalnız **gerçekten** medya üstündeki metne
> düşüyor (kapsama ≥ %85). İlk denemede daha gevşek bir kuralla krem zemin ve
> pembe kart üstündeki yazılara da hap düşmüştü — sonuç hapsız halinden kötüydü;
> kök neden kesişim testinin `> 0` olmasıydı (2,8e-17 birimlik kayan nokta
> artığı "medya üstünde" sayılıyordu). 15 regresyon testi gerçek şablonlara
> katman adıyla kilitli.

Gerçek export'ta doğruladım: açık renkli bir medya üstünde beyaz
"YAZ İNDİRİMİ" başlığı zor okunuyor.

Filigran bu sorunu çözmek için koyu hap + halo aldı
([TemplateExporter.swift:375](TemplateKit/Sources/TemplateKit/Render/TemplateExporter.swift:375)
yorumu bunu açıkça anlatıyor) — ama **şablon metinleri aynı korumayı almadı**.
Kullanıcı parlak bir fotoğraf seçtiğinde başlık kaybolur ve suçu uygulamaya
atar.

### 2.4 — Müzik bir satış argümanı değil

21 parça `AudioSynth` ile çalışma anında sentezleniyor. Mühendislik olarak
zekice: telif riski sıfır, deterministik, paket şişmiyor. Lisans alınmama
kararı da (YAPILACAKLAR §2) **doğru** — o lisansı zaten üçüncü parti bir
editör veremez.

Ama kullanıcı tarafında sonuç şu: bunlar seçilecek şarkılar değil, **altlık**.
Paywall'daki üç vaatten biri "Tüm müzikler" — sentez altlıklara erişim satmak
zayıf kalıyor. Pro'nun değeri fiilen "filigran + kilitli şablonlar"a iniyor.

### 2.5 — Katalogun %62'si gerçek cihazda hiç denenmedi

79/127 şablon iki geçişli montaj yolunu kullanıyor ve bu yol simulator'da
çalışmıyor (belgeli kısıt).

**Bunu somut olarak gördüm:** montaj şablonunu ücretsiz kullanıcıyla export
ettim, sonuç ekranı metinleriyle birlikte doğru görünüyordu — ama diskteki
MP4'ü açtığımda **ne metin ne filigran** vardı, sadece ham medya. Ekrandaki
metin canlı SwiftUI overlay'i (`MontagePreviewOverlay`), dosyanın içeriği
değil.

Bu simulator kısıtı olarak biliniyor ve doğru belgelenmiş. Riskli olan şu:
**simulator testi bu yolda yanlış güven veriyor.** Cihazda bir aksama olursa
ücretsiz kullanıcı filigransız video alır — yani Pro'nun ana gerekçesi sessizce
buharlaşır. Cihaz testi yapılmadan hiçbir şey yayınlanmamalı.

### 2.6 — Marka hiçbir yere uygulanmamış

> **DURUM: KOD TARAFI ÇÖZÜLDÜ.** `AppInfo.displayName` ve
> `CFBundleDisplayName` = **Kadraj**, filigran "Made with Kadraj" (export
> edilen videonun pikselinde teyitli), deep link `kadraj://`. **Pages hâlâ
> kapalı:** `unverfirat.github.io/kadraj/{kosullar,gizlilik,destek}.html`
> bugün üçü de 404 döndü (depo var, `docs/*.html` commit'li — eksik olan
> deponun Pages ayarı). **Bilinçli dokunulmayanlar:** bundle id
> (`com.storytemplate.app`) ve ürün ID'leri — ASC kaydından sonra
> değişmiyorlar, karar senin. İkon ve ASC abonelik ürünleri de açık.

Export ettiğim videonun pikselinde filigran aynen şöyle yazıyor:
**"Made with StoryTemplate"**. Ayrıca:

- `CFBundleDisplayName` = `StoryTemplate`, `AppInfo.displayName` = `StoryTemplate`
- bundle id `com.storytemplate.app`, deep link `storytemplate://`
- İkon: turuncu bir kart + oynat üçgeni — jenerik placeholder, marka değil
- `Legal.swift`'teki üç URL, Pages açılmadığı için 404
- Ödeme arka ucu varsayılan `local`: "Ücretsiz denemeyi başlat" hiçbir satın
  alma yapmadan Pro veriyor (test sırasında yanlışlıkla ben de tetikledim)

### 2.7 — Katalog koyu ve tekdüze

Şablonların büyük çoğunluğu siyaha yakın. Arka arkaya 127 tanesini kaydırınca
hepsi birbirine benziyor. Rakip galerilerinin canlılığı yok. Ortalama süre
6,7 sn — Story için uygun, Reels için kısa.

### 2.8 — İlk açılışta karşılama yok

> **DURUM: ÇÖZÜLDÜ.** 3 karelik, her karede atlanabilir bir karşılama
> (`OnboardingView`). "İlk videon filigransız" rozeti yalnız hak duruyorsa
> çıkıyor — Pro'ya yanlış vaat vermiyor. `smoke.sh` otomasyonu
> `--skip-onboarding` ile geçiyor.

Uygulama doğrudan 127 kartlık duvara açılıyor. "Bu ne işe yarar / bak 20
saniyede böyle bir şey çıkıyor" anı yok.

---

## 3. Satın alır mıydım? — gerekçeli

| Soru | Cevap |
|---|---|
| Ürün işimi görüyor mu? | Tipografi şablonlarında evet, fotoğraflılarda henüz hayır |
| Değerini denemeden anladım mı? | **Hayır** — paywall'a üretim yapmadan çarptım |
| Pro üç vaadinin kaçı beni ikna ediyor? | 1,5 / 3 (filigran evet, şablonlar kısmen, müzik hayır) |
| Fiyat makul mü? | Koddaki ₺79,99/ay – ₺399,99/yıl **placeholder**; gerçek fiyat ASC'den gelecek. Ama bu bant, Türkiye'de esnafa aylık abonelik olarak yüksek. Yıllık tek seferlik daha kolay satar. |
| Bir daha açar mıyım? | Taslak/"Devam et" şeridi iyi kurgulanmış — evet, eğer ilk seferde bir sonuç almışsam |

**Beni ödemeye ikna edecek en küçük değişiklik:** ilk videoyu ücretsiz,
filigransız, kilitsiz bitirtmek. Sonra filigranı koymak. İnsan elde ettiği
şeyi kaybetmemek için öder; görmediği şey için ödemez.

---

## 4. Plan

Sıra önem sırasıdır — yukarıdakiler aşağıdakilerin değerini belirler.

### P0 — Cihaz doğrulaması (her şeyden önce)

Bu yapılmadan aşağıdakilerin hiçbirine yatırım yapma; sonuçları geçersiz olur.

- [ ] **Gerçek cihazda montaj export'u.** 79 şablonun yolu. Kontrol listesi:
      metin gömülüyor mu, **ücretsiz kullanıcıda filigran var mı**, ses doğru
      mu, klip hızı + trim + kadraj birlikte doğru mu.
- [ ] Ritim dönüşümü uygulanmış 50 şablonun cihazda görünümü.
- [ ] Bellek/ısınma profili (montaj + otomatik önizleme yenileme birlikte).
- [ ] 4:5 / 1:1 yeniden kadrajlama cihazda.

### P1 — Vitrin (dönüşümü en çok etkileyen iş)

- [ ] **Örnek medya havuzunu büyüt: 5 → 40-60 kare.** Kategorilere göre
      dağıt (yemek, mekân, kuaför/güzellik, moda, emlak, spor, gezi, kutlama).
      **Açık — P1'in asıl yarısı bu.** `tools/samples/source/` hâlâ **5 gerçek
      fotoğraf** (iki şehir, bir yemek, iki doku); 15 örnek klibin geri kalanı
      üretilmiş soyut sahne. Siluetin gitmesi
      "bozuk" hissini kaldırdı ama "senin fotoğrafın buraya gelecek" hissini
      vermiyor.
- [x] **`.portrait` silueti vitrinden kalktı** — yerine yumuşak plato fonu +
      cyclorama kavisi. `spa-calm-01`, `makeup-look-01` posterlerinde gözle
      teyit, sonra 40 şablonluk kontak baskısıyla katalog geneli tarandı.
      **Yüzsüz ama gerçek insan kareleri (arkadan baş, omuz üstü, çalışan
      eller) hâlâ açık** — lisans/model izni kararı gerekiyor.
- [ ] Lisans disiplinini koru: her kare için `CREDITS.md` girdisi. Pexels /
      Unsplash / Wikimedia CC0 kullanılabilir — **ticari kullanım ve model izni
      şartlarını kare kare doğrula**, mevcut eleme kuralın (marka, filigran,
      tanınabilir kişi) aynen kalsın.
- [x] Varlıkları yeniden üret — 254 poster + 254 önizleme, iki dilde.
      **Sıra önemli:** poster üretimi `SampleClips.swift`'ten değil
      `tools/samples/*.mp4`'ten besleniyor; önce `--make-samples`. Bu adım ilk
      turda atlandığı için siluet posterlerde kalmıştı.
      Manifest `version`'ları **bilinçli artırılmadı** (77×v1, 50×v2): CDN
      henüz yayınlanmadı, yani ortada önbellek yok. İlk yayından sonraki her
      yeniden üretimde artırılmalı — cache anahtarı `id-vN`.
- [x] Kontak baskısıyla gözle denetle — `tools/contact/sheet-*.png`.
- [ ] Katalogun koyuluk dengesi: her kategoriye en az birkaç açık/canlı şablon.
      **Açık** (§2.7).

### P2 — Huni (ikinci en yüksek etki)

- [x] **İlk video ücretsiz ve filigransız.** Bir kerelik hak
      (`hasFirstFreeExport`). Temiz kurulum → filigransız çıktı; hak
      harcanmışken → filigranlı. İkisi de export edilmiş MP4'ün pikselinde
      doğrulandı, `FirstFreeExportTests` ile kilitlendi.
- [x] Paywall sonuç ekranında; galerideki üst bant ilk export'a kadar gizli
      (galeride bant görünmediği uygulamada teyit edildi).
- [x] **Ücretsiz/Pro dengesi:** 70 / 57, her kategori ≥ %50.
      Sosyal 6/21 → **11/21**, İş 2/7 → **4/7**. Lint temiz.
- [x] **Karşılama:** 3 kare, her karede "Atla", sonunda galeriye.
      Ana düğme beyaz — altın bu uygulamada Pro'nun rengi, karşılamada
      kullanılmadı.
- [ ] Pro'nun üçüncü vaadini gözden geçir: müzik zayıfsa yerine somut bir şey
      koy (ör. 4:5 / 1:1 yeniden kadraj, toplu export, yeni şablonlara erken
      erişim). **Açık.**

### P3 — Kalite cilası

- [x] **Metin okunabilirliği:** hap yalnız medyayı **≥ %85** kapsayan metin
      katmanına düşüyor; emoji sticker'lar hariç. 15 regresyon testi gerçek
      şablonlara katman adıyla kilitli + 3 poster gözle teyit edildi
      (§2.3'teki kayan nokta hatası bu yüzden çıktı: testler geçerken poster
      bozuktu).
- [x] **Rozet/metin zamanlaması:** plaka ile etiket birlikte giriyor.
      Sorun sistemikmiş — 136 plaka/etiket çiftinin **135'inde** plaka önce
      giriyordu. Boşluğu bu analizde "~2 sn" diye yazmıştım (oynatıcıda scrub
      ederek tahmin); kare kare ölçüm **0,15–0,2 sn** dedi. Sorun gerçekti,
      büyüklük tahmini yanlıştı.
- [ ] Süreleri gözden geçir (ort. 6,7 sn) — Reels için 8-12 sn seçeneği.
      **Açık.**

### P4 — Marka ve mağaza (MAGAZA.md ile birlikte)

- [x] `AppInfo.displayName`, `CFBundleDisplayName` → **Kadraj**
- [x] **Filigran metni** → "Made with Kadraj" — export edilen videonun
      pikselinde teyitli
- [ ] Bundle id kararı (`com.kadraj.app`) — **bilinçli dokunulmadı**, ASC
      kaydından sonra değişmiyor; ürün ID'leri de aynı sebeple bekliyor
- [x] Deep link şeması → `kadraj://`
- [ ] Gerçek ikon (1024 + tüm boyutlar)
- [ ] **GitHub Pages'i aç** → üç yasal URL'yi doğrula. Depo ve `docs/*.html`
      yerinde ama Pages ayarı kapalı: bugün üçü de **404** döndü.
- [ ] ASC'de abonelik ürünleri → `BillingBackend.resolved` varsayılanını
      `.storeKit` yap
- [ ] Fiyatlandırma: yıllığı öne çıkar; aylığı Türkiye bandına göre yeniden
      düşün
- [ ] Ekran görüntüleri — **P1 bitmeden çekme**, yoksa vitrin sorununu
      mağazaya taşırsın

---

## 5. Tek cümlelik özet

Motor bitmiş, ürün bitmemiş: Kadraj'ın eksiği kod değil, **kullanıcıya kendi
işini gösteren bir vitrin ve para istemeden önce bir kere kazandıran bir
huni** — ikisi de birkaç günlük iş, ve ikisi olmadan bu uygulamanın kalitesi
kimseye görünmüyor.
