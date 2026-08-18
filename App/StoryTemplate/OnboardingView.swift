import SwiftUI
import TemplateKit

/// İlk açılış karşılaması: üç kare, huninin tamamı.
///
/// NEDEN VAR: uygulama ilk açılışta doğrudan yüzlerce kartlık şablon duvarına
/// açılıyordu. Kullanıcı ne yapacağını değil, neyi seçmesi gerektiğini görüyor
/// ve "bu ne işe yarıyor" sorusunun cevabını kartlardan çıkarmak zorunda
/// kalıyordu. Üç kare bu boşluğu dolduruyor — daha fazlası değil: karşılama
/// ekranı ürünün kendisi değil, kapısı.
///
/// NEDEN SATIŞ YOK: paywall burada AÇILMAZ ve plan/fiyat gösterilmez. Ürünün
/// huni kararı "değer önce, teklif sonra" (bkz. `GalleryView.proBanner` ve
/// `ExportResultView.firstFreeCard`); ilk dokunuşta yapılan teklif dönüşmüyor,
/// uygulamayı sildiriyor. Son karedeki "ilk videon filigransız" satırı teklif
/// değil, VAAT — kullanıcı bir şey satın almadan ne alacağını öğreniyor.
struct OnboardingView: View {
    @EnvironmentObject var store: Store

    /// Karşılama bittiğinde çağrılır — "Atla" ile de, "Hadi başlayalım" ile de
    /// AYNI yer: galeri. İki çıkışın farklı yere gitmesi, atlayan kullanıcıyı
    /// cezalandırmak olurdu.
    let onFinish: () -> Void

    @State private var page = 0

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
    }

    /// Kareler galerideki huni cümlesiyle AYNI kelimeleri kullanır ("Bir şablon
    /// seç, medyanı koy, paylaş"). Kullanıcı karşılamada öğrendiği üç adımı iki
    /// saniye sonra galeri başlığının altında tekrar görüyor — aynı şeyi iki
    /// ayrı dille anlatmak, öğrenilen adımı boşa harcamak olurdu.
    private var steps: [Step] {
        [Step(id: 0, icon: "square.grid.2x2.fill",
              title: String(localized: "Şablon seç"),
              detail: String(localized: "Yemek, indirim, emlak, kutlama… Hazır şablonlar arasından işine uyanı seç.")),
         Step(id: 1, icon: "photo.on.rectangle.angled",
              title: String(localized: "Medyanı koy"),
              detail: String(localized: "Fotoğraflarını ve videolarını ekle, yazıları kendi sözlerinle değiştir.")),
         Step(id: 2, icon: "square.and.arrow.up.fill",
              title: String(localized: "Paylaş"),
              detail: String(localized: "Videon saniyeler içinde hazır. Doğrudan paylaş ya da galerine kaydet."))]
    }

    private var isLastPage: Bool { page == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(steps) { step in
                    stepView(step).tag(step.id)
                }
            }
            // Kendi noktalarımızı çiziyoruz: sistem göstergesi koyu zeminde
            // düğmenin üstüne biniyor ve son karede "bitti mi" bilgisini
            // vermiyor.
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.bottom, 26)
            footer
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        // KAÇIŞ YOLU HER ZAMAN GÖRÜNÜR — paywall'daki kapatma düğmesiyle aynı
        // yerde, aynı gerekçeyle: tuzağa düşürülmüş hisseden kullanıcı ekranı
        // değil uygulamayı kapatıyor. Son karede de durur, çünkü orada
        // kaybolması "artık mecbursun" demek olurdu.
        .overlay(alignment: .topTrailing) {
            Button {
                Haptics.tap()
                onFinish()
            } label: {
                Text("Atla")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
            .padding(.top, 14)
        }
    }

    // MARK: - Kare

    private func stepView(_ step: Step) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#F2C14E").opacity(0.20),
                                                  .white.opacity(0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1))
                    .frame(width: 168, height: 168)
                Image(systemName: step.icon)
                    .font(.system(size: 62, weight: .regular))
                    .foregroundStyle(Color(hex: "#F2C14E"))
            }

            // `verbatim`: yalnız rakam var, çeviri katalogunda anahtar açmasın.
            Text(verbatim: "\(step.id + 1) / \(steps.count)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 26)

            Text(step.title)
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 8)

            Text(step.detail)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 34)
                .padding(.top, 10)

            // Vaat YALNIZ hak dururken gösterilir: Pro kullanıcıya ya da hakkını
            // çoktan harcamış birine (`--onboarding` ile ekranı yeniden açan)
            // "ilk videon filigransız" demek yanlış bilgi olurdu.
            if isLastPageStep(step), store.entitlements.hasFirstFreeExport {
                firstFreeNote.padding(.top, 22)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func isLastPageStep(_ step: Step) -> Bool { step.id == steps.count - 1 }

    /// `ExportResultView.firstFreeCard` ile aynı söz, aynı ikon: kullanıcı bu
    /// cümleyi ilk videosunun sonunda birebir tekrar görecek.
    private var firstFreeNote: some View {
        HStack(spacing: 7) {
            Image(systemName: "gift.fill").font(.system(size: 12))
            Text("İlk videon filigransız")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Color(hex: "#F2C14E"))
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color(hex: "#F2C14E").opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: "#F2C14E").opacity(0.30), lineWidth: 1))
    }

    // MARK: - Alt kısım

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(steps) { step in
                Capsule()
                    .fill(step.id == page ? Color.white : Color.white.opacity(0.22))
                    .frame(width: step.id == page ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.18), value: page)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        Button {
            Haptics.tap()
            if isLastPage {
                onFinish()
            } else {
                withAnimation(.easeOut(duration: 0.22)) { page += 1 }
            }
        } label: {
            // Ternary içindeki literal `LocalizedStringKey` yerine `String`e
            // çözülebiliyor; çeviri kaçmasın diye açıkça istiyoruz.
            Text(isLastPage ? String(localized: "Hadi başlayalım")
                            : String(localized: "Devam"))
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        // BEYAZ, altın değil. Altın bu uygulamada Pro'nun rengi
        // (`PaywallView`); karşılamanın ana düğmesini altın yapmak, ücretsiz
        // bir adımı satın alma düğmesi gibi göstermek olurdu.
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.black)
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }
}

/// Karşılamanın "bir kez" kuralının sahibi.
///
/// NEDEN AYRI BİR TİP: kural iki soruya birden cevap veriyor — kullanıcı bunu
/// gördü mü ve bu açılış OTOMASYON mu (duman testi / ekran görüntüsü akışı).
/// İkisini `RootView` içinde dağıtmak, bayrak listesinin zamanla kaymasına ve
/// otomasyonun sessizce karşılama ekranına takılmasına açık kapı bırakırdı.
struct OnboardingGate {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "onboarding.seen") {
        self.defaults = defaults
        self.key = key
    }

    /// Kayıt yokken `false` — yeni kurulumda karşılama gösterilir.
    var hasSeen: Bool { defaults.bool(forKey: key) }

    /// Karşılama BİTİRİLDİĞİNDE (Atla dâhil) yazılır, gösterildiğinde değil:
    /// kullanıcı ilk açılışta uygulamayı okumadan kapattıysa tanıtımı bir daha
    /// hiç görmemesi için bir sebep yok.
    func markSeen() { defaults.set(true, forKey: key) }

    /// Testler ve `--onboarding` bayrağı için.
    func reset() { defaults.removeObject(forKey: key) }

    /// Otomasyonun kullandığı başlatma bayrakları.
    ///
    /// Bunlardan biri verildiyse karşılama GÖSTERİLMEZ. `App/Scripts/smoke.sh`
    /// ve ekran görüntüsü akışı uygulamayı doğrudan galeriye/editöre açıp
    /// ekranı yakalıyor; araya giren tam ekran bir tanıtım o akışları kilitler.
    /// Aynı gerekçe deep link için de geçerli değil — deep link uygulama zaten
    /// açıkken gelir, karşılama kararı ise açılışta bir kez verilir.
    private static let automationFlags = ["--route", "--inject-media", "--inject-video",
                                          "--open-videos", "--open-settings",
                                          "--open-paywall", "--open-music", "--open-picker",
                                          "--pro", "--free", "--used-free-export"]

    /// Bu açılışta karşılama gösterilmeli mi.
    ///
    /// Sıra önemli: açık "atla" her şeyi yener (otomasyonun elinde kesin bir
    /// kapatma anahtarı olmalı), sonra açık "göster" gelir (ekran görüntüsü
    /// almak için bayrağı zorlayan kişi ekranı görmek istiyordur), sonra
    /// otomasyon sezgisi, en sonda gerçek kullanıcı kuralı.
    static func shouldPresent(arguments: [String] = ProcessInfo.processInfo.arguments,
                              gate: OnboardingGate = OnboardingGate()) -> Bool {
        if arguments.contains("--skip-onboarding") { return false }
        if arguments.contains("--onboarding") {
            // Zorla göstermek, "bir kez" kaydını da temizler: bayrak olmadan
            // yapılan bir sonraki açılış gerçek ilk açılışı taklit etsin.
            gate.reset()
            return true
        }
        if arguments.contains(where: { automationFlags.contains($0) }) { return false }
        return !gate.hasSeen
    }
}
