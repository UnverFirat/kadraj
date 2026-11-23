durum: geliştirme
özet: Kadraj — kod büyük ölçüde hazır; cihaz doğrulaması (A–G), App Store Connect kaydı ve GitHub Pages bekliyor; 3 aydır dokunulmadı
güncelleme: 2026-11-23
ad: Kadraj
---
## Nerede kaldık
iOS native (SwiftUI + AVFoundation) şablonlu hikâye/reel video uygulaması. 127 şablon, TR+EN, 151 test yeşil. Bundle id kararı `com.fireflysoftware.kadraj`. Son çalışma 27–30 Ağustos'ta cihaz turu (oynatıcı sızıntısı, çıkışta çökme düzeltildi). Tek sayfalık özet `DURUM.md`. Bekleyen 16 commit 23 Kasım'da pushlandı.
## Sıradaki
- [ ] Cihaz doğrulaması A–F (ses başlamamalı, tek render, ses üst üste binmemeli, müzik kapatma, çıkışta çökme, ısınma)
- [ ] G: montaj export'unun metinli çıktısı — 79 şablon cihazda hiç görülmedi (en kritik)
- [ ] App Store Connect: uygulama + abonelik ürünleri, sonra `BillingBackend.resolved = .storeKit`
- [ ] GitHub Pages aç (Settings → Pages → main /docs) — gizlilik sayfası 404 = kesin ret
- [ ] CDN yükleme (`tools/publish-cdn.sh`) ve `TemplateCDNBaseURL`
- [ ] Crash reporting sağlayıcısı seç
## Bitenler
- [x] 16 commit pushlandı (23 Kasım)
- [x] Vitrin gerçek fotoğraflara geçti (55 CC0 foto, 254 poster)
- [x] Kullanıcı turu kusurları düzeltildi
- [x] Cihaz turu: oynatıcı sızıntısı, otomatik önizleme, çıkışta çökme
- [x] Müzik kararı: lisans alınmayacak, 21 sentez parça
## Engeller / notlar
- Kod borcu: EditorView ~1750 satır, ExportLibrary.add ana thread'de
- Paywall fiyatları (₺399,99 / ₺79,99) koda gömülü sahte değerler
