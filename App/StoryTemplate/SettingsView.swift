import SwiftUI
import StoreKit
import TemplateKit

/// Ayarlar: abonelik durumu, satın alımları geri yükleme, uygulamayı
/// değerlendirme/paylaşma ve yasal bağlantılar. Mağaza ile ilgili her şey
/// `Store` üzerinden gider (SDK burada da yok — `EntitlementProvider` seam'i
/// korunur).
///
/// Burada bilinçli olarak OLMAYAN şey: şablon kataloğunun kaynağı ("29 şablon ·
/// uygulama paketi", "Liste sunucudan (CDN) yönetilir…") ve "Şablonları yenile"
/// düğmesi. Bunlar bizim altyapımız; kullanıcı ne CDN'i ne önbelleği bilir ve
/// bir listeyi elle tazelemesi de gerekmez (galeride aşağı çekince yenileniyor).
/// Geliştirme sırasında görmek için aşağıdaki DEBUG bölümü duruyor.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var library: DemoLibrary
    @EnvironmentObject var exports: ExportLibrary
    @Environment(\.requestReview) private var requestReview

    @State private var restoreResult: String?
    @State private var showShare = false
    #if DEBUG
    @State private var isRefreshing = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ayarlar")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.bottom, 14)

                subscriptionCard
                supportSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [Legal.shareMessage, Legal.appStoreURL])
        }
    }

    // MARK: - Abonelik

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: store.entitlements.isPro ? "crown.fill" : "crown")
                    .foregroundStyle(Color(hex: "#F2C14E"))
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.entitlements.isPro ? "Pro üyelik aktif" : "Ücretsiz sürüm")
                        .font(.system(size: 16, weight: .semibold))
                    Text(statusDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }

            if !store.entitlements.isPro {
                Button {
                    Haptics.tap()
                    store.showPaywall(reason: String(localized: "Tüm şablonları aç"))
                } label: {
                    Text("Pro'ya geç")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(hex: "#F2C14E"), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            } else {
                // Pro kullanıcı aboneliğini yönetebilmeli — App Store kuralı
                // olmasa da güven meselesi: iptal yolunu saklamayız.
                Link(destination: Legal.manageSubscriptionsURL) {
                    Text("Aboneliği yönet")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }

            Button {
                Task {
                    let ok = await store.restore()
                    ok ? Haptics.success() : Haptics.warning()
                    restoreResult = ok ? String(localized: "Aboneliğin geri yüklendi.")
                                       : String(localized: "Geri yüklenecek bir abonelik bulunamadı.")
                }
            } label: {
                Text("Satın alımları geri yükle")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if let restoreResult {
                Text(restoreResult)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(hex: "#F2C14E").opacity(store.entitlements.isPro ? 0.45 : 0.2),
                    lineWidth: 1))
        .padding(.bottom, 22)
    }

    private var statusDetail: String {
        if store.status.inTrial { return String(localized: "Deneme süresi devam ediyor") }
        if store.entitlements.isPro {
            return String(localized: "Tüm şablonlar, tüm müzikler, filigransız")
        }
        return String(localized: "Filigranlı dışa aktarım · sınırlı şablon")
    }

    // MARK: - Destek / büyüme

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Uygulama"))
            // Değerlendirme istemi kullanıcıyı App Store'a ATMAZ; sistem
            // penceresi uygulamanın içinde açılır (SKStoreReview) — en az
            // rahatsız eden yol.
            actionRow(icon: "star", title: String(localized: "Uygulamayı değerlendir")) {
                requestReview()
            }
            actionRow(icon: "square.and.arrow.up",
                      title: String(localized: "Arkadaşlarına öner")) {
                Haptics.tap()
                showShare = true
            }
            linkRow(icon: "questionmark.circle", title: String(localized: "Yardım ve destek"),
                    url: Legal.supportURL)
        }
        .padding(.bottom, 22)
    }

    // MARK: - Hakkında

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Hakkında"))
            row(icon: "film.stack",
                title: exports.items.isEmpty
                    ? String(localized: "Henüz video oluşturmadın")
                    : String(localized: "\(exports.items.count) video · \(exports.totalSizeText)"),
                detail: String(localized: "Videolar yalnızca cihazında saklanır."))
            // Gizlilik politikası ve kullanım koşullarına uygulama İÇİNDEN de
            // erişilebilmeli (App Store yalnız mağaza sayfasındaki bağlantıyla
            // yetinmiyor).
            linkRow(icon: "hand.raised", title: String(localized: "Gizlilik Politikası"),
                    url: Legal.privacyPolicyURL)
            linkRow(icon: "doc.text", title: String(localized: "Kullanım Koşulları"),
                    url: Legal.termsURL)
            Text(String(localized: "Sürüm \(AppInfo.version)"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
    }

    private func linkRow(icon: String, title: String, url: URL) -> some View {
        Link(destination: url) {
            rowLabel(icon: icon, title: title, trailing: "arrow.up.right.square")
        }
    }

    private func actionRow(icon: String, title: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(icon: icon, title: title, trailing: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
        .contentShape(Rectangle())
    }

    // MARK: - Geliştirici (yalnız DEBUG)

    #if DEBUG
    /// Katalog kaynağı ve analitik olayları: sahada gözle doğrulamak için.
    /// Yayınlanan uygulamada bu bölüm hiç derlenmez.
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(String(localized: "Geliştirici (debug)"))
            row(icon: "shippingbox", title: library.status.label,
                detail: String(localized: "Liste sunucudan (CDN) yönetilir; çevrimdışıyken önbellek kullanılır."))
            // CDN bağlı değilse seed listesinde OLMAYAN şablonların posteri
            // hiç gelmez ve kartlar kalıcı olarak yer tutucuya düşer —
            // yayına öyle çıkmamak için burada görünür duruyor.
            row(icon: library.cdnBase == nil ? "wifi.slash" : "icloud",
                title: library.cdnBase?.absoluteString
                    ?? String(localized: "CDN yapılandırılmamış"),
                detail: library.cdnBase == nil
                    ? String(localized: "Seed dışı şablonların posteri gelmez (bkz. docs/cdn-deployment.md).")
                    : String(localized: "Posterler ve şablonlar buradan tazeleniyor."))
            Button {
                isRefreshing = true
                Task {
                    await library.load()
                    isRefreshing = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Şablonları yenile").font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)

            let lines = AppAnalytics.recent.lines(limit: 12)
            if lines.isEmpty {
                row(icon: "waveform", title: String(localized: "Henüz olay yok"),
                    detail: String(localized: "Bir şablon aç, video oluştur — olaylar burada birikir."))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 22)
    }
    #endif

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail).font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
