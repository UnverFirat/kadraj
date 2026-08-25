import SwiftUI
import TemplateKit

/// Paywall: Pro'nun ne açtığını gösterir, plan seçtirir, satın alma/geri
/// yükleme akışını `Store` üzerinden yürütür.
///
/// Ürün/fiyat bilgisi sağlayıcıdan gelir (mağaza lokalize eder) — bu ekranda
/// sabit fiyat yazılmaz.
struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    /// Paywall'ı hangi eylem tetikledi ("Bu şablon Pro" gibi).
    let reason: String?
    @State private var selected: SubscriptionPlan = .yearly
    @State private var restoreFailed = false

    /// (ikon, başlık, açıklama). Metinler String olduğu için (Text literali
    /// değil) çeviri açıkça istenir.
    private var benefits: [(String, String, String)] {
        [("square.grid.2x2.fill", String(localized: "Tüm şablonlar"),
          String(localized: "Pro şablonların hepsi açılır")),
         ("drop.fill", String(localized: "Filigransız dışa aktarım"),
          String(localized: "Videolarında logo kalmaz")),
         ("music.note.list", String(localized: "Tüm müzikler"),
          String(localized: "Kütüphanenin tamamı kullanılabilir")),
         ("sparkles", String(localized: "Yeni şablonlar"),
          String(localized: "Yayınlandığı gün erişim"))]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // BOŞLUKLAR SIKI: 393×852'lik bir iPhone'da sheet açılır
                // açılmaz güven satırlarının sonuncusu ("Videoların yalnızca
                // cihazında kalır") sabit düğmenin başladığı yerde yarım
                // kalıyordu. Kaydırınca görünüyordu ama ilk kare kesik bir
                // satır gösteriyordu — hem de ticari olarak en önemli ekranda,
                // tam da güven vermesi gereken satırda. Ölçüler bu yüzden
                // dolgudan ve dikey aralıklardan kısıldı; düğme sabit kaldı.
                VStack(spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { icon, title, detail in
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(hex: "#F2C14E"))
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title).font(.system(size: 15, weight: .semibold))
                                    Text(detail).font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                            }
                        }
                    }
                    plans
                    reassurance
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                // Kaydırma GEREKEN küçük ekranlarda son satır düğmeye
                // yapışmasın diye altta biraz nefes payı kalır.
                .padding(.bottom, 12)
            }
            footer
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        // Kapatma düğmesi: kaçış yolu ekranın SOL/SAĞ ÜSTÜNDE, ilk bakışta
        // görünür olmalı. Altta küçük gri "Şimdi değil" satırı, tuzağa
        // düşürülmüş hissi veriyordu — ve o his aboneliği değil, uygulamayı
        // sildiriyor.
        .overlay(alignment: .topTrailing) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Kapat"))
            .padding(.trailing, 18)
            .padding(.top, 14)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(hex: "#F2C14E"))
                .padding(.top, 4)
            Text("Pro'ya geç")
                .font(.system(size: 28, weight: .bold))
            Text(reason ?? "Tüm şablonlar, tüm müzikler, filigransız video")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var plans: some View {
        VStack(spacing: 10) {
            // Gerçek mağazada ürünler asenkron gelir. Fiyat mağazadan gelmeden
            // plan göstermek yok — uydurulmuş fiyat hem yanıltıcı hem App Store
            // kuralına aykırı.
            if store.products.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Fiyatlar yükleniyor…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            }
            // Önerilen plan ÜSTTE durur: seçili olan planın listenin altında
            // kalması, kullanıcıya önce reddetmek istediği seçeneği okutuyor.
            ForEach(sortedProducts) { product in
                let isSelected = selected == product.plan
                Button {
                    Haptics.select()
                    selected = product.plan
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected
                              ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(isSelected
                                             ? Color(hex: "#F2C14E") : .white.opacity(0.3))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(product.plan == .yearly ? String(localized: "Yıllık") : String(localized: "Aylık"))
                                    .font(.system(size: 16, weight: .semibold))
                                // Tek bir yönlendirme etiketi. Uydurma bir
                                // yüzde yerine mağazadan gelen "ayda X"
                                // satırıyla desteklenen dürüst bir ipucu.
                                if product.plan == .yearly, store.products.count > 1 {
                                    Text("EN AVANTAJLI")
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(Color(hex: "#F2C14E").opacity(0.22), in: Capsule())
                                        .foregroundStyle(Color(hex: "#F2C14E"))
                                }
                            }
                            Text(Self.periodText(for: product))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(product.priceText)
                                .font(.system(size: 16, weight: .semibold))
                            if product.trialDays > 0 {
                                Text("\(product.trialDays) gün ücretsiz")
                                    .font(.system(size: 10, weight: .heavy))
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Color(hex: "#F2C14E"), in: Capsule())
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(isSelected ? 0.12 : 0.06),
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected
                                ? Color(hex: "#F2C14E") : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Planlarla düğme arasındaki boşluğu dolduran güven satırı. Uydurma bir
    /// "10.000 kullanıcı" iddiası değil — hepsi uygulamanın doğrulanabilir
    /// gerçekleri (hesap yok, veri cihazda kalıyor, iptal tek dokunuş).
    private var reassurance: some View {
        VStack(spacing: 9) {
            ForEach(Self.assurances, id: \.1) { icon, text in
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 16)
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
            }
        }
        .padding(.top, 4)
    }

    private static var assurances: [(String, String)] {
        [("xmark.circle", String(localized: "İstediğin an iptal edebilirsin")),
         ("person.crop.circle.badge.xmark", String(localized: "Hesap açmana gerek yok")),
         ("iphone", String(localized: "Videoların yalnızca cihazında kalır"))]
    }

    private var footer: some View {
        VStack(spacing: 9) {
            Button {
                guard let product = store.products.first(where: { $0.plan == selected })
                else { return }
                Haptics.tap()
                Task {
                    await store.purchase(product)
                    if store.entitlements.isPro { Haptics.success() }
                }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text(selectedProductHasTrial ? "Ücretsiz denemeyi başlat" : "Pro'ya geç")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            .background(Color(hex: "#F2C14E"), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.black)
            .disabled(store.isPurchasing || store.products.isEmpty)
            .opacity(store.products.isEmpty ? 0.5 : 1)

            HStack(spacing: 18) {
                Button("Geri yükle") {
                    Task { restoreFailed = !(await store.restore()) }
                }
                Button("Şimdi değil") { dismiss() }
            }
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.55))

            if restoreFailed {
                Text("Geri yüklenecek abonelik bulunamadı.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // App Store'un satın alma ekranında aradığı zorunlu bilgi:
            // süre, fiyat, otomatik yenileme, iptal yolu + EULA ve gizlilik
            // bağlantıları (Guideline 3.1.2). Eksikse uygulama ret alır.
            Text(Legal.subscriptionDisclosure(for: selectedProduct))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Link("Kullanım Koşulları", destination: Legal.termsURL)
                Text("·").foregroundStyle(.white.opacity(0.25))
                Link("Gizlilik Politikası", destination: Legal.privacyPolicyURL)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24).padding(.bottom, 10)
    }

    /// Plan satırının ikinci satırı. Mağazadan gelen `periodText` MOTOR
    /// paketinde kuruluyor ve orada çeviri katalogu yok — metni burada,
    /// uygulamanın dilinde kuruyoruz (fiyatın kendisi mağazadan geldiği gibi).
    private static func periodText(for product: SubscriptionProduct) -> String {
        switch product.plan {
        case .monthly:
            return String(localized: "aylık")
        case .yearly:
            guard let perMonth = product.pricePerMonthText else {
                return String(localized: "yıllık")
            }
            return String(localized: "yıllık · ayda \(perMonth)")
        }
    }

    /// Yıllık önce, aylık sonra.
    private var sortedProducts: [SubscriptionProduct] {
        store.products.sorted { lhs, _ in lhs.plan == .yearly }
    }

    private var selectedProduct: SubscriptionProduct? {
        store.products.first { $0.plan == selected }
    }

    private var selectedProductHasTrial: Bool {
        selectedProduct.map { $0.trialDays > 0 } ?? false
    }
}
