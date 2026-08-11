import SwiftUI
import AVKit
import UIKit
import TemplateKit

/// "Videolarım": kullanıcının oluşturduğu videolar (poster ızgarası).
/// Dokun → oynat / paylaş / sil.
struct MyVideosView: View {
    @EnvironmentObject var exports: ExportLibrary
    @State private var playing: ExportItem?
    /// Silme onayı bekleyen video. Video kullanıcının EMEĞİ ve tek kopyası
    /// burada; onaysız silme geri alınamaz bir kayıp demek.
    @State private var pendingDelete: ExportItem?
    /// Boş durumdaki düğme kullanıcıyı Şablonlar sekmesine götürür.
    var onBrowseTemplates: () -> Void = {}

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Videolarım")
                    .font(.system(size: 34, weight: .bold))
                Text(exports.items.isEmpty
                     ? "Oluşturduğun videolar burada birikir"
                     : "\(exports.items.count) video · \(exports.totalSizeText) · cihazında saklanıyor")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                if exports.items.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(exports.items) { item in
                            Button {
                                Haptics.tap()
                                playing = item
                            } label: {
                                VideoCard(item: item, poster: exports.posterURL(item))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { pendingDelete = item } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $playing) { item in
            VideoDetailView(item: item,
                            url: exports.videoURL(item),
                            onDelete: { pendingDelete = item })
        }
        .confirmationDialog(Text("Bu video silinsin mi?"),
                            isPresented: Binding(get: { pendingDelete != nil },
                                                 set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if let item = pendingDelete {
                    exports.remove(item)
                    Haptics.success()
                }
                pendingDelete = nil
                playing = nil
            }
            Button("Vazgeç", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Bu işlem geri alınamaz. Fotoğraflar'a kaydettiysen oradaki kopya kalır.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.25))
            Text("Henüz video yok")
                .font(.system(size: 16, weight: .semibold))
            Text("Bir şablon seç, kendi fotoğraf ve videolarını ekle —\ngerisini biz hallederiz.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            // Boş ekran kullanıcıya yalnız "şuraya git" DEMEMELİ, oraya
            // götürmeli.
            Button {
                Haptics.tap()
                onBrowseTemplates()
            } label: {
                Label("Şablonlara göz at", systemImage: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color(hex: "#F2C14E"), in: Capsule())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct VideoCard: View {
    let item: ExportItem
    let poster: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.08))
                if let image = UIImage(contentsOfFile: poster.path) {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "film").font(.title)
                        .foregroundStyle(.white.opacity(0.4))
                }
                // Oynat rozeti KÖŞEDE durur. Ortadaki büyük daire, kullanıcının
                // kendi videosunun tam da en önemli yerini (başlığını, yüzünü)
                // kapatıyordu — oysa bu ızgarada bakılacak şey işin kendisi.
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                    Text("\(String(format: "%.0f", item.duration)) sn")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(8)
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.templateName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(Self.dateText(item.createdAt))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private static func dateText(_ date: Date) -> String {
        // Tarih biçimi cihazın diline/bölgesine göre (sabit "tr_TR" değil).
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

/// Tam ekran oynatıcı + paylaş/sil.
private struct VideoDetailView: View {
    let item: ExportItem
    let url: URL
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showShare = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VideoPlayer(player: player)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)

                if let saveMessage {
                    Text(saveMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 12) {
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Sil", systemImage: "trash")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)

                    // Paylaş menüsünden de kaydedilebiliyor ama "Fotoğraflar'a
                    // kaydet" beklenen birincil eylem — ayrı düğme hak ediyor.
                    Button { save() } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Kaydet", systemImage: "square.and.arrow.down")
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .disabled(isSaving)

                    Button { showShare = true } label: {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .background(Color(hex: "#F2C14E"), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(item.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) { ShareSheet(items: [url]) }
            .onAppear {
                let p = AVPlayer(url: url)
                player = p
                p.play()
            }
            .onDisappear { player?.pause() }
        }
    }

    private func save() {
        isSaving = true
        saveMessage = nil
        Task {
            let outcome = await PhotoSaver.save(videoAt: url)
            isSaving = false
            saveMessage = PhotoSaver.message(for: outcome)
        }
    }
}

/// UIActivityViewController köprüsü (paylaş / Fotoğraflar'a kaydet).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
