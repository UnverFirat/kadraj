import SwiftUI
import TemplateKit

struct GalleryView: View {
    @EnvironmentObject var library: DemoLibrary
    @EnvironmentObject var store: Store
    @EnvironmentObject var drafts: DraftStore
    /// nil = tüm kategoriler.
    @State private var category: String?
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var visibleProjects: [DemoProject] {
        var result = library.projects
        if let category {
            result = result.filter { $0.template.category == category }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return result }
        return result.filter { $0.matches(trimmed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Şablonlar")
                    .font(.system(size: 34, weight: .bold))
                Text("Bir şablon seç, medyanı koy, paylaş")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 14)

                searchField
                    .padding(.bottom, 12)

                // TEKLİF DEĞERDEN SONRA GELİR. Kullanıcı henüz tek bir video
                // üretmediyse bu bant, karşılığını görmediği bir şeyin
                // reklamıdır — ilk açılışta ekranda şablonlar olmalı, satış
                // değil. İlk video bitince (bkz. `Store.hasFinishedAVideo`)
                // bant belirir: artık neyi satın aldığı belli.
                if !store.entitlements.isPro, store.hasFinishedAVideo { proBanner }
                if library.projects.isEmpty {
                    catalogPlaceholder
                }
            }
            .padding(.horizontal, 20)

            // YARIM KALMIŞ İŞLER en üstte: kullanıcının geri dönme sebebi bu.
            // Katalogun en tepesinde durur çünkü "devam et", "yeni bir şablon
            // seç"ten daha değerli bir eylem.
            if !drafts.drafts.isEmpty, isBrowsingAll { draftStrip }

            // Çipler kenardan kenara kaysın: 20 pt'lik gövde dolgusunun içine
            // hapsedilince son çip kenarda YARIM kalıyor ve kaydırılabilir
            // olduğu anlaşılmıyordu.
            categoryChips
                .padding(.bottom, 14)

            // 100 şablonluk düz bir ızgara "sonu gelmeyen duvar" hissi veriyor
            // ve kullanıcı aradığı işi (yemek? emlak? kutlama?) gözle taramak
            // zorunda kalıyor. Süzgeç yokken katalog kategori kategori
            // bölünür; süzülmüşse zaten kısa bir liste var, düz ızgara yeter.
            if isBrowsingAll {
                ForEach(sections, id: \.category) { section in
                    sectionHeader(section)
                    grid(section.projects)
                        .padding(.bottom, 22)
                }
            } else {
                grid(visibleProjects)
            }

            if visibleProjects.isEmpty, !library.projects.isEmpty {
                noMatchState
            }
        }
        .scrollDismissesKeyboard(.immediately)
        // Şablon listesini tazelemenin doğal yeri burası. Eskiden bunun tek
        // yolu Ayarlar'daki "Şablonları yenile" düğmesiydi — kullanıcının
        // aklına gelmeyecek bir yer.
        .refreshable { await library.load() }
        .background(Color.black.ignoresSafeArea())
    }

    /// Süzgeçsiz gezinme: kategori seçili değil ve arama boş.
    private var isBrowsingAll: Bool {
        category == nil && query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Devam et (taslaklar)

    private var draftStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Devam et")
                    .font(.system(size: 20, weight: .bold))
                Text("\(drafts.drafts.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(drafts.drafts) { draft in
                        // Taslağın şablonu katalogdan kalkmış olabilir (CDN'den
                        // çekilmiş bir şablon kaldırıldı): o kartı gösterme.
                        if library.project(templateID: draft.templateID) != nil {
                            NavigationLink(value: Route.editor(templateID: draft.templateID,
                                                               autoExport: false)) {
                                DraftCard(draft: draft)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                            .contextMenu {
                                Button(role: .destructive) {
                                    drafts.remove(templateID: draft.templateID)
                                } label: {
                                    Label("Taslağı sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    private struct Section {
        let category: String
        let projects: [DemoProject]
    }

    /// Katalog, `TemplateCategory.order` sırasında bölümlere ayrılır; bölüm
    /// içinde manifest sırası (yani editoryal sıra) korunur.
    private var sections: [Section] {
        let grouped = Dictionary(grouping: library.projects, by: \.template.category)
        return TemplateCategory.sorted(grouped.keys).compactMap { name in
            guard let projects = grouped[name], !projects.isEmpty else { return nil }
            return Section(category: name, projects: projects)
        }
    }

    private func sectionHeader(_ section: Section) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(TemplateCategory.label(section.category)
                .resolved(languageCode: AppLanguage.code))
                .font(.system(size: 20, weight: .bold))
            Text("\(section.projects.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            Button {
                Haptics.select()
                withAnimation(.easeOut(duration: 0.18)) { category = section.category }
            } label: {
                Text("Tümünü gör")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private func grid(_ projects: [DemoProject]) -> some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(projects) { project in
                // Kilitli şablon editöre gitmez, paywall'ı açar
                // (keşif ücretsiz, kullanım Pro).
                if store.entitlements.isLocked(project.template) {
                    Button {
                        Haptics.warning()
                        store.showPaywall(
                            reason: String(localized: "\(project.template.name.resolved(languageCode: AppLanguage.code)) Pro şablon"))
                    } label: {
                        TemplateCard(project: project, locked: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(cardLabel(project, locked: true)))
                } else {
                    NavigationLink(value: Route.editor(templateID: project.id,
                                                       autoExport: false)) {
                        TemplateCard(project: project, locked: false)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(cardLabel(project, locked: false)))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Arama

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            TextField(String(localized: "Şablon ara (tarif, indirim, gezi…)"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                // Arama kutusunda ilk harfi büyütmek ("Tarif") hem gereksiz
                // hem de kullanıcıyı düzeltmeye zorluyor.
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Aramayı temizle"))
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var noMatchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.22))
            Text("Eşleşen şablon yok")
                .font(.system(size: 16, weight: .semibold))
            Text("Başka bir kelime dene ya da filtreyi kaldır.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                query = ""
                category = nil
            } label: {
                Text("Filtreleri temizle")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    /// VoiceOver kart etiketi: kart içindeki rozetler tek tek okunmak yerine
    /// tek cümlede toplanır ("Reel Kolaj, 5 klip · 12 sn, Pro").
    private func cardLabel(_ project: DemoProject, locked: Bool) -> String {
        let name = project.template.name.resolved(languageCode: AppLanguage.code)
        let base = "\(name), \(project.subtitle)"
        return locked ? base + ", " + String(localized: "Pro") : base
    }

    /// Şablon listesi boşken: yükleniyor mu, yoksa gerçekten bir sorun mu var?
    /// (Katalog paketten geldiği için bu ekran normalde hiç görünmez; ama bozuk
    /// bir CDN yayını ya da eksik paket kaynağında kullanıcı boş bir sayfaya
    /// değil, ne olduğunu söyleyen bir ekrana bakmalı.)
    @ViewBuilder private var catalogPlaceholder: some View {
        VStack(spacing: 12) {
            switch library.status {
            case .loading:
                ProgressView().tint(.white)
                Text("Şablonlar yükleniyor…")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
            default:
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Şablonlar açılamadı")
                    .font(.system(size: 16, weight: .semibold))
                Text("İnternet bağlantını kontrol edip tekrar dener misin?")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { Task { await library.load() } } label: {
                    Label("Tekrar dene", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    /// Kategori filtresi. Kategoriler şablonlardan (yani manifestten) gelir —
    /// sunucu yeni kategori yayınlayınca çip kendiliğinden çıkar.
    private var categoryChips: some View {
        let categories = TemplateCategory.sorted(library.projects.map(\.template.category))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: String(localized: "Tümü"), selected: category == nil) { category = nil }
                ForEach(categories, id: \.self) { name in
                    chip(title: TemplateCategory.label(name).resolved(languageCode: AppLanguage.code),
                         selected: category == name) {
                        category = category == name ? nil : name
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.18)) { action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.white : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Ücretsiz kullanıcıya Pro girişi (galerinin üstünde, tek satır).
    private var proBanner: some View {
        Button {
            Haptics.tap()
            store.showPaywall(reason: String(localized: "Tüm şablonları aç"))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color(hex: "#F2C14E"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pro'ya geç").font(.system(size: 14, weight: .semibold))
                    Text("Kilitli şablonlar, tüm müzikler, filigransız video")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#F2C14E").opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
    }
}

struct TemplateCard: View {
    let project: DemoProject
    var locked: Bool = false
    @EnvironmentObject var thumbnails: ThumbnailStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                poster
                // Kartta TEK rozet var.
                //
                // Eskiden aynı kartta üç rozet birden olabiliyordu
                // (KOLAJ + PRO + POPÜLER) ve bunlardan "KOLAJ / KLASİK" zaten
                // kartın altındaki satırı tekrar ediyordu. Üç rozet posterin
                // üstünü kaplayıp şablonun kendisini görünmez yapıyordu —
                // oysa kullanıcının bakması gereken tek şey şablonun nasıl
                // göründüğü. Kilit her şeyin önüne geçer, sonra manifest
                // rozeti gelir.
                badge.padding(10)
            }
            .aspectRatio(9.0/16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                if locked {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.25))
                        .allowsHitTesting(false)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.template.name.resolved(languageCode: AppLanguage.code))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(project.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var badge: some View {
        if project.template.isPro {
            Label("PRO", systemImage: "lock.fill")
                .font(.system(size: 9, weight: .heavy))
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(Color(hex: "#F2C14E"), in: Capsule())
                .foregroundStyle(.black)
        } else if let tag = project.tags.first {
            Text(tag == "new" ? String(localized: "YENİ") : String(localized: "POPÜLER"))
                .font(.system(size: 9, weight: .heavy))
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(.white.opacity(0.92), in: Capsule())
                .foregroundStyle(.black)
        }
    }

    /// Kart görseli: `templatekit-assets` ile üretilmiş poster (CDN/paket).
    /// Poster yoksa ya da henüz yüklenmediyse şablonun katmanlarından çizilen
    /// `TemplatePreview` gösterilir — kart hiçbir zaman boş kalmaz ve
    /// uygulamanın hiç tanımadığı bir CDN şablonu da doğru görünür.
    @ViewBuilder private var poster: some View {
        if let entry = project.entry, let image = thumbnails.image(for: entry) {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            TemplatePreview(template: project.template, texts: project.texts,
                            photos: project.photoSlots, videos: project.videoSlots)
                .task(id: project.entry?.cacheKey) {
                    if let entry = project.entry { await thumbnails.load(entry) }
                }
        }
    }
}


extension Color {
    /// Palet rengi: "#RRGGBB" veya "#RRGGBBAA" (motordaki `RGBAColor` ile aynı
    /// sözleşme). Alfa'yı yok saymak scrim/gradient renklerini düz renge
    /// çeviriyordu — "#000000CC" parlak maviye dönüşüyordu.
    init(hex: String) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        let value = UInt64(s, radix: 16) ?? 0
        let hasAlpha = s.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255,
                  opacity: hasAlpha ? Double(value & 0xFF) / 255 : 1)
    }
}


/// "Devam et" şeridindeki kart: taslağın ilk medyası + şablon adı + ne zaman.
private struct DraftCard: View {
    let draft: Draft
    @EnvironmentObject var drafts: DraftStore
    @State private var image: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.08)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.65)],
                               startPoint: .center, endPoint: .bottom)
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(draft.mediaCount)")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(8)
            }
            .frame(width: 104, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.14), lineWidth: 1))

            Text(draft.templateName)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text(Self.relative(draft.updatedAt))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 104)
        .task(id: draft.updatedAt) {
            // Poster çözmek (özellikle video karesi) ana iş parçacığında
            // yapılmamalı: galeri kaydırılırken takılıyor.
            guard let first = draft.slots.first else { return }
            let url = drafts.fileURL(first.fileName)
            let isPhoto = first.kind == .photo
            image = await Task.detached(priority: .userInitiated) {
                isPhoto ? DraftStore.decodePhoto(at: url) : VideoPoster.firstFrame(of: url)
            }.value
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(draft.templateName), yarım kalmış iş, \(draft.mediaCount) medya"))
    }

    private static func relative(_ date: Date) -> String {
        // Bir dakikadan yeni kayıtlar "az önce": formatter sıfıra yuvarlayınca
        // "0 sn. sonra" gibi (gelecek zamanlı!) bir metin üretiyor.
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return String(localized: "az önce") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
