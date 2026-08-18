# Mağazaya çıkış dosyası — Kadraj

App Store Connect'te (ASC) sorulan **her alanın hazır cevabı** burada. Sırayla
kopyala-yapıştır; koda dokunması gereken adımlar `→ kod` ile işaretli.

> **Ad kararı:** Uygulama adı **Kadraj** olarak öneriliyor (gerekçe: TR'de
> "kadraj" = kadrajlama/çerçeveleme, video işiyle doğrudan ilgili; kısa,
> akılda kalır, App Store'da aynı adla bir uygulama görünmüyor; EN'de de
> telaffuz edilebiliyor). Kodda uygulandı: `AppInfo.displayName`,
> `CFBundleDisplayName`, filigran metni ve URL şeması (`kadraj://`).
> Bundle id ve abonelik ürün ID'leri `com.fireflysoftware.kadraj*` olarak
> sabitlendi (2026-08-18) — bunlar
> ASC'ye bağlı, aşağıdaki "Yapılacaklar" bölümünde ayrı karar.

---

## 1. Uygulama kimliği

| Alan | Değer |
|---|---|
| App Store adı (max 30) | `Kadraj: Hikâye Şablonları` (TR) · `Kadraj: Story Templates` (EN) |
| Alt başlık (max 30) | `Hikâye ve reel şablonları` (TR) · `Story & reel video templates` (EN) |
| Bundle ID | `com.fireflysoftware.kadraj` — **karar verildi (2026-08-18)**, kodda uygulandı. Diğer üç uygulamayla aynı yayıncı öneki (`lumijournal`, `smallstart`, `quarterlyTaxEstimator`). ASC'de uygulama oluşturulduktan sonra DEĞİŞMEZ |
| SKU | `kadraj-ios-01` |
| Birincil kategori | Fotoğraf ve Video |
| İkincil kategori | İş (Business) |
| Yaş sınırı | 4+ (şiddet/küfür/kumar yok, kullanıcı içeriği paylaşımı uygulama içinde yok) |
| Diller | Türkçe (birincil), İngilizce |
| Fiyat | Ücretsiz + uygulama içi abonelik |

## 2. Açıklama metinleri

### Türkçe — tanıtım metni (max 170)
```
127 hazır şablon: indirim duyurusundan menüye, emlak ilanından davetiyeye. Medyanı koy, yazını değiştir, videon hazır. Hesap gerekmez.
```

### Türkçe — açıklama
```
Kadraj, işini anlatan hikâye ve reel videolarını dakikalar içinde hazırlar.
Tasarım bilmene gerek yok: hazır bir şablon seç, fotoğraf veya videonu ekle,
yazıları kendi işine göre değiştir — gerisini Kadraj yapar.

NE İŞE YARAR
• İndirim ve kampanya duyuruları
• Kafe/restoran menüsü, günün yemeği, paket servis
• Emlak ilanı, daire künyesi, açık ev
• Kuaför, güzellik salonu, tırnak sanatı randevu kartları
• Davetiye, doğum günü, yıl dönümü, bayram tebriği
• Müşteri yorumu, öncesi-sonrası, iş ilanı, kurs duyurusu
• Gezi günlüğü, fotoğraf albümü, müzik tanıtımı

NEDEN KADRAJ
• 127 şablon, 14 kategori — hepsi Türkçe hazırlanmış, İngilizce de var
• Şablonun tüm renklerini tek dokunuşla değiştir
• Videonun kendi sesini koru ya da uygulamadaki müziklerden seç
• Metinler otomatik sığar; uzun yazıda taşma olmaz
• Fotoğraf ve videon telefonundan ÇIKMAZ — her şey cihazda işlenir
• Hesap açmak yok, kayıt yok, veri toplama yok

İLK VİDEON BİZDEN
İlk videonu filigransız dışa aktarıyorsun — denemek için abonelik gerekmiyor.
Şablonların 70'i zaten ücretsiz.

PRO
Pro aboneliğiyle filigran kalkar, kilitli şablonlar ve tüm müzikler açılır.
Aylık ya da yıllık; istediğin an Ayarlar → Abonelikler'den iptal edebilirsin.

Sorular ve öneriler: destek@kadraj.app
```

### English — promotional text (max 170)
```
127 ready-made templates: sales, menus, listings, invitations. Drop in your media, edit the text, your video is done. No account, nothing leaves your phone.
```

### English — description
```
Kadraj turns your photos and clips into story and reel videos in minutes.
No design skills needed: pick a template, add your media, edit the text for
your own business — Kadraj does the rest.

WHAT IT'S FOR
• Sales and campaign announcements
• Cafe and restaurant menus, dish of the day, delivery
• Real estate listings, property specs, open house
• Salon, beauty and nail studio booking cards
• Invitations, birthdays, anniversaries, holiday greetings
• Testimonials, before-after, job posts, course promos
• Travel diaries, photo albums, music promos

WHY KADRAJ
• 127 templates in 14 categories, in English and Turkish
• Recolor a whole template with one tap
• Keep your clip's original audio or pick an in-app track
• Text auto-fits — long copy never overflows the frame
• Your photos and videos NEVER leave your phone; everything renders on device
• No account, no sign-up, no data collection

YOUR FIRST VIDEO IS ON US
Your first export is watermark-free — no subscription needed to try it.
70 of the templates are free anyway.

PRO
A Pro subscription removes the watermark and unlocks locked templates and all
music. Monthly or yearly, cancel any time in Settings → Subscriptions.

Questions and feedback: destek@kadraj.app
```

### Anahtar kelimeler (100 karakter, virgülle, boşluksuz)
- TR: `hikaye,reels,şablon,video,kolaj,tanıtım,indirim,menü,emlak,davetiye,montaj,işletme,story`
- EN: `story,reels,template,video,collage,promo,sale,menu,realestate,invite,editor,business,maker`

> Marka adı yazma (ad alanı zaten indeksleniyor), rakip marka adı YAZMA
> (CapCut/InShot vb. → ret sebebi).

### Sürüm notları (1.0)
- TR: `İlk sürüm. 127 şablon, 14 kategori, Türkçe ve İngilizce.`
- EN: `First release. 127 templates in 14 categories, English and Turkish.`

## 3. Uygulama gizliliği (App Privacy) — ASC anketi cevapları

| Soru | Cevap |
|---|---|
| Bu uygulama veri topluyor mu? | **Hayır — "Data Not Collected"** |
| Takip (tracking) yapıyor mu? | Hayır. IDFA kullanılmıyor, ATT istemi yok |
| Üçüncü parti SDK | Yok (RevenueCat SDK'sı EKLENMEDİ; yalnız protokol var) |
| Gizlilik politikası URL | `https://unverfirat.github.io/kadraj/gizlilik.html` |

Kodda karşılığı: `App/StoryTemplate/PrivacyInfo.xcprivacy` — izleme yok, toplanan
veri yok, required-reason API'leri (UserDefaults `CA92.1`, dosya zaman damgası,
boş disk alanı) gerekçeleriyle bildirilmiş. **Analitik sağlayıcı eklenirse bu
tablo, `.xcprivacy` ve gizlilik sayfası BİRLİKTE güncellenir.**

## 4. Abonelikler (In-App Purchase)

Abonelik grubu: `Kadraj Pro`

| Ürün | Ürün ID (kodla eşleşmeli) | Süre | Deneme |
|---|---|---|---|
| Pro Aylık | `com.fireflysoftware.kadraj.pro.monthly` | 1 ay | 3 gün |
| Pro Yıllık | `com.fireflysoftware.kadraj.pro.yearly` | 1 yıl | 3 gün |

> Bundle ID'yi `com.kadraj.*` yapacaksan ürün ID'lerini de **ASC'de ürünleri
> oluşturmadan önce** değiştir; ürün ID'si sonradan değişmiyor. Kod tarafında
> iki yer: `TemplateKit/Sources/TemplateKit/Billing/StoreKitEntitlementProvider.swift`
> (varsayılan `monthlyProductID`/`yearlyProductID`) ve `App/StoryTemplate.storekit`
> (Xcode'dan koşarken kullanılan test yapılandırması).

Yerelleştirilmiş isim/açıklama (her ikisi de zorunlu):

- TR — Pro Aylık: `Kadraj Pro (Aylık)` / `Filigransız dışa aktarma, kilitli şablonlar ve tüm müzikler.`
- TR — Pro Yıllık: `Kadraj Pro (Yıllık)` / `Yıllık planla en avantajlı fiyat: filigransız video, tüm şablonlar ve müzikler.`
- EN — Monthly: `Kadraj Pro (Monthly)` / `Watermark-free exports, locked templates and all music.`
- EN — Yearly: `Kadraj Pro (Yearly)` / `Best value: watermark-free videos, every template and all music.`

Fiyatlandırma önerisi (karar senin): aylık orta segment, yıllık ≈ 6 aylık fiyatı
(≈ %50 indirim algısı). Yıllık planı öne çıkar — paywall "EN AVANTAJLI"
etiketini mağazadan gelen fiyata göre gösteriyor, **fiyat metni koda yazılmıyor**.

Gözden geçirme ekran görüntüsü: paywall ekranının bir görüntüsü ASC'de her ürün
için isteniyor (`App/Scripts/smoke.sh` çıktısındaki `07-paywall.png` kullanılabilir).

## 5. Ekran görüntüleri

Gereken boyutlar ASC'de listeleniyor (bugün itibarıyla 6.9" ve 6.5" iPhone
zorunlu; iPad desteklemiyoruz). Üretim:

```bash
DEVICE="iPhone 17 Pro Max" ./App/build.sh --no-run && OUT=~/Desktop/kadraj-shots App/Scripts/smoke.sh
```

Önerilen 6 kare ve üstlerine yazılacak başlık:

1. Galeri (kategorilere bölünmüş kartlar) — “127 hazır şablon”
2. Editör, gerçek fotoğrafla — “Medyanı koy, yazını değiştir”
3. Renk paneli açık — “Tek dokunuşla tüm renkler”
4. Müzik sekmesi — “Kendi sesin ya da hazır müzik”
5. Sonuç ekranı (video hazır) — “İlk videon filigransız”
6. Kategori filtresi / arama — “İşine uygun şablonu bul”

> **Ekran görüntülerini gerçek fotoğraf havuzu bitmeden çekme.** Galeri
> posterleri bugün hâlâ 5 gerçek fotoğraftan üretiliyor; kare 1 ve 2 bu haliyle
> vitrin sorununu doğrudan mağazaya taşır
> (`KULLANICI-ANALIZI.md` §2.1 ve P1).

## 6. App Review bilgileri

- **Demo hesabı gerekmiyor** (uygulama hesapsız çalışır) → "Sign-in required: No"
- Notlar (kopyala):
```
Uygulama hesap gerektirmez ve internet bağlantısı olmadan da çalışır.
Tüm video işleme cihazda yapılır; sunucuya veri gönderilmez.
Pro aboneliği filigranı kaldırır ve kilitli şablonları açar; satın alma
ekranındaki fiyat ve yenileme bilgisi App Store'dan gelir.
Örnek görseller kamu malı / CC0 kaynaklıdır, künyesi depoda
tools/samples/source/CREDITS.md içinde tutulur.
```
- İletişim: ad, telefon, e-posta (ASC'de zorunlu)

## 7. Diğer ASC alanları

| Alan | Cevap |
|---|---|
| İhracat uyumluluğu (şifreleme) | `ITSAppUsesNonExemptEncryption = false` (Info.plist'te var) → ASC'de "Hayır" |
| İçerik hakları | "Üçüncü taraf içeriği içermiyor" (şablonlar ve müzik bize ait, örnek görseller CC0/kamu malı) |
| Reklam kimliği (IDFA) | Kullanılmıyor |
| Destek URL | `https://unverfirat.github.io/kadraj/destek.html` |
| Pazarlama URL (isteğe bağlı) | `https://unverfirat.github.io/kadraj/` |
| Telif hakkı | `2026 Fırat Ünver` |

## 8. Google Play / diğer mağazalar

Bu depo **native iOS** (Swift + AVFoundation + Core Animation). Play Store'a
çıkmak yeni bir uygulama yazmak demek (motorun Android karşılığı yok).
Şablon formatı (`docs/template-format.md`) platformdan bağımsız olduğu için
şablonlar ve katalog aynen kullanılabilir; render motoru yeniden yazılmalı.
Kısa vadede önerilmiyor.

---

## Yapılacaklar (sırayla)

- [x] **Ad onayı** → `AppInfo.displayName` ve `CFBundleDisplayName` = `Kadraj`
      (`App/StoryTemplate/Legal.swift`, `App/Info.plist`); filigran varsayılanı
      `Made with Kadraj`, URL şeması `kadraj://` → kod
- [ ] **Bundle ID kararı** (`com.kadraj.app`?) — ASC'de uygulama oluşturmadan önce → kod
- [ ] **Abonelik ürün ID kararı** (`com.kadraj.pro.monthly/.yearly`?) — ürün ID'si
      ASC'de oluşturulduktan sonra değişmiyor, bundle id ile birlikte karara bağla → kod
- [ ] **İkon** (1024×1024 + tüm boyutlar) — ad kesinleşince üretilir → kod
- [ ] **GitHub Pages'i aç**: Settings → Pages → Source: `main` / klasör: `/docs`
- [ ] **Yasal URL'ler** `Legal.swift` içinde Pages adresine çekildi ✓ (Pages açılınca doğrula)
- [ ] **destek@kadraj.app** adresini kur (ya da sayfalardaki adresi kendi adresinle değiştir)
- [ ] **ASC'de abonelik ürünlerini oluştur** → sonra `BillingBackend.resolved`
      varsayılanını `.storeKit` yap → kod
- [ ] **Gerçek cihazda export smoke testi** (simulator'da montajın 2. geçişi çöküyor)
- [ ] **Ekran görüntüleri** (yukarıdaki 6 kare) + mağaza metinlerini ASC'ye gir
- [ ] **Posterleri/önizlemeleri CDN'e yükle** (`tools/publish-cdn.sh`,
      `docs/cdn-deployment.md`) ve `Info.plist` → `TemplateCDNBaseURL` doldur → kod
- [ ] **Crash reporting seçimi** (opsiyonel; seçilirse gizlilik beyanı da güncellenir)
- [ ] TestFlight turu → App Review'a gönder
