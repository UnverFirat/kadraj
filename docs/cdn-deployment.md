# Şablon dağıtımı: ne pakette, ne sunucuda

Bu doküman katalogun nereden geldiğini ve yayına çıkarken ne yapılacağını
anlatır. Karar tek cümlede: **şablon TARİFLERİ uygulamayla gelir, şablon
GÖRSELLERİ sunucudan.**

## Neden

Şablon dosyalarının kendisi çok küçük — 100 şablonun JSON'u toplam **~1 MB**.
Ağırlık galeri posterlerinde: her şablonun iki dilde bir posteri var ve 100
şablonda bu **~17 MB** ediyor. Önizleme videoları (`previews/*.mp4`) ise tek
başına **85 MB**.

Katalog büyüdükçe bu doğrusal artıyor: 300 şablonda posterler 50 MB'ı geçer.
Uygulamanın indirme boyutunu içerik sayısına bağlamak sürdürülebilir değil —
üstelik kullanıcı o şablonların çoğunu hiç açmayacak.

Bu yüzden bölüşüm şöyle:

| Ne | Nerede | Boyut | Gerekçe |
|---|---|---|---|
| Şablon JSON'ları (hepsi) | uygulama paketi | ~1 MB | Katalog listesi ilk açılışta ve çevrimdışında EKSİKSİZ görünsün |
| `manifest.json` | paket + CDN | ~40 KB | Paketteki seed, CDN'deki güncel |
| Seed posterleri (~28 şablon) | uygulama paketi | ~3 MB | Galerinin İLK ekranı ağ beklemeden dolu görünsün |
| Diğer posterler | **CDN** | — | İlk görüntülemede inip önbelleğe alınır |
| Önizleme videoları | **CDN** | 85 MB | Uygulamaya hiç girmez |
| Lottie varlıkları | paket + CDN | 24 KB | Şablon paketten geliyorsa animasyonu da gelmeli |

Sonuç: uygulama paketi **26 MB → 18 MB** (simulator debug ölçümü; App Store'a
giden thinned/sıkıştırılmış boyut daha küçük olur). Katalog 300 şablona
çıksa bile paket boyutu **artmaz** — yalnız seed listesi belirler.

Hangi posterlerin pakete gireceği `templates/seed-posters.txt` ile seçilir
(kategori başına 1-2 iş). Liste yorumlarla birlikte kendini anlatıyor.

**Poster inmemişken kart BOŞ KALMAZ:** `TemplateCard`, poster yoksa
`TemplatePreview`'a düşer ve şablonu kendi katmanlarından çizer. Yani ağ yoksa
galeri sade ama dolu görünür; poster gelince kart kendiliğinden zenginleşir.

## Uygulama tarafı nasıl çalışıyor (zaten hazır)

`TemplateCatalog` sırası her zaman **önbellek → seed → ağ**:

1. Uygulama, indirilmiş manifest/şablonlarla ağ beklemeden açılır.
2. Önbellek boşsa uygulamayla gelen (seed) katalog gösterilir.
3. Arka planda manifest tazelenir (`ETag`/`If-None-Match`; 304 gelirse
   önbellek korunur). Ağ hatası listeyi BOZMAZ, yalnız tazeleme atlanır.
4. İndirilen şablon `TemplateValidator`'dan geçmeden önbelleğe yazılmaz —
   bozuk bir yayın kullanıcıyı kilitleyemez.
5. Manifestten düşen ya da sürümü geçen şablon/poster önbellekten silinir
   (`pruneCachedTemplates`).

Önbellek `Caches/` altında: iOS disk baskısında kendisi temizler, uygulamanın
ayrıca kota yönetmesi gerekmez.

**Sürümleme:** önbellek anahtarı `id-vN`. İçerik değiştirdiysen manifestteki
`version`'ı ELLE artır, yoksa istemci eski sürümü kullanmaya devam eder.
`minAppVersion` ise yeni motor özelliği isteyen şablonu eski uygulamalardan
gizler — yani uygulama güncellemeden şablon yayınlamak güvenlidir.

## CDN adresi

`App/Info.plist` → `TemplateCDNBaseURL`. Boşsa uygulama ağa hiç çıkmaz ve
YALNIZ paketle gelen şablon/posterlerle çalışır.

```
--cdn <url>            (başlatma bayrağı, geliştirme — Info.plist'i ezer)
TemplateCDNBaseURL     (Info.plist, ürün)
boş                    → yalnız paket
```

> **YAYIN ÖNCESİ ZORUNLU:** `TemplateCDNBaseURL` doldurulmadan yayına
> çıkılırsa seed listesinde OLMAYAN ~70 şablonun kartı kalıcı olarak sade
> `TemplatePreview` yedeğiyle görünür. Ya CDN'i bağla ya da seed listesini
> genişlet — ikisinden biri şart.

## Yayınlama

```bash
tools/publish-cdn.sh                  # dist/cdn hazırla + tutarlılık doğrula
tools/publish-cdn.sh --with-previews  # önizleme mp4'lerini de al (~85 MB)
```

Script önce lint ve manifest tutarlılığını doğrular (manifestte olup dosyası
olmayan ya da dosyası olup manifestte olmayan şablon varsa durur), sonra
yüklenecek ağacı üretir:

```
dist/cdn/
  manifest.json
  <id>.json …            # şablon tarifleri
  thumbs/<id>.jpg        # kaynak dil (tr)
  thumbs/en/<id>.jpg     # diğer diller
  assets/*.json          # lottie
  previews/<id>.mp4      # (--with-previews ile)
```

Statik dosya barındıran her yer olur (S3 + CloudFront, Cloudflare R2, Bunny,
hatta GitHub Pages). Gereken tek şey HTTPS ve doğru cache başlıkları:

| Yol | `Cache-Control` | Neden |
|---|---|---|
| `manifest.json` | `public, max-age=300` | Katalog değişikliği hızlı yayılsın; ETag zaten var |
| `<id>.json`, `thumbs/**`, `previews/**` | `public, max-age=31536000, immutable` | İçerik `id-vN` ile sürümleniyor; aynı URL asla değişmez |

```bash
aws s3 sync dist/cdn s3://<bucket>/v1/ --delete \
    --cache-control "public, max-age=31536000, immutable"
aws s3 cp dist/cdn/manifest.json s3://<bucket>/v1/manifest.json \
    --cache-control "public, max-age=300"
```

Doğrulama:

```bash
curl -sI https://cdn.ornek.com/v1/manifest.json | head -1        # 200
cd App && ./build.sh -- --cdn https://cdn.ornek.com/v1
```

Ayarlar → Geliştirici (debug) bölümü katalogun o an nereden geldiğini
gösterir: "uygulama paketi" / "önbellek (çevrimdışı)" / "güncellendi".

## Sonraki adımlar (henüz yapılmadı)

- **Önizleme videoları galeriye bağlı değil.** `previews/*.mp4` üretiliyor ve
  manifest yolu yayınlıyor ama uygulama bunları hiç indirmiyor; kart basılı
  tutunca oynayan bir önizleme iyi bir sonraki adım olurdu.
- **Şablon paketi (zip).** CDN'den inen bir şablon lottie varlığı taşıyorsa
  o varlık şu an yalnız uygulama paketinden gelebiliyor. Format dokümanındaki
  `package` alanı (template.json + thumbnail + assets tek zip) bunu çözecek.
- **Bölgesel/A-B katalog.** Manifest tek dosya; ileride kullanıcı diline veya
  ülkesine göre farklı sıralama sunmak istenirse `manifest-<locale>.json`
  yeterli olur, istemci tarafı değişmez.
