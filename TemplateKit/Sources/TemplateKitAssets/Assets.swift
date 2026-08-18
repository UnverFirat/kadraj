import Foundation
import TemplateKit
import TemplateKitLottie
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Galeri varlıklarını üretir: her şablon için `thumbs/<id>.jpg` (poster karesi)
/// ve `previews/<id>.mp4` (kısa döngü). `manifest.json` bu iki yolu zaten
/// yayınlıyordu ama dosyalar depoda yoktu — CDN kırık link veriyordu.
///
/// Şablonun KENDİ varsayılan metinleriyle render eder (elle yazılmış demo
/// içeriği yok): CDN'e yeni bir şablon koyduğunda varlıkları da aynı komutla
/// çıkar, uygulamada hiçbir şey değişmez.
///
/// Medya slotları depodaki örnek kliplerle doldurulur; foto slotlarına aynı
/// kliplerin bir karesi konur (gerçek görüntü, sentetik gradyandan çok daha
/// temsili bir vitrin görseli verir).
///
/// Kullanım (TemplateKit dizininden; release ÇOK daha hızlı):
///   swift run -c release templatekit-assets
///   swift run -c release templatekit-assets --only quote-01
///   swift run -c release templatekit-assets --lang en --width 720
@main
struct Assets {
    static func main() async throws {
        let options = Options(CommandLine.arguments)

        // Örnek klipleri (yeniden) üret. Vitrin varlıklarının içine giren bu
        // klipler dağıtıldığı için hak zinciri bizde olmalı — bkz.
        // SampleClipGenerator.
        if options.makeSamples {
            print("Örnek klipler üretiliyor → \(options.samplesDirectory.path)")
            try await SampleClipGenerator.generateAll(in: options.samplesDirectory)
            print("Bitti. Şimdi varlıkları yenile: swift run -c release templatekit-assets")
            return
        }

        // Poster ve önizlemeler lottie katmanlarını da göstersin.
        LottieRendererRegistry.install(
            LottieAdapter(searchDirectories: [options.templatesDirectory]))

        let manifestURL = options.templatesDirectory.appendingPathComponent("manifest.json")
        let manifest = try JSONDecoder().decode(TemplateManifest.self,
                                                from: Data(contentsOf: manifestURL))

        // Vitrin varlıkları DİLE BAĞLI: poster şablonun metinlerini gösteriyor,
        // İngilizce cihazda Türkçe poster görünmemeli. Kaynak dil (tr) kök
        // klasöre, diğer diller alt klasöre yazılır (`thumbs/en/…`) — katalog
        // da önce dilin klasörüne bakar, yoksa köke düşer.
        let languagePath = options.language == Options.sourceLanguage ? "" : "/\(options.language)"
        let thumbsDirectory = options.templatesDirectory
            .appendingPathComponent("thumbs\(languagePath)")
        let previewsDirectory = options.templatesDirectory
            .appendingPathComponent("previews\(languagePath)")
        for directory in [thumbsDirectory, previewsDirectory] {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
        }
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("templatekit-assets-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        let media = try await MediaPool(samplesDirectory: options.samplesDirectory)
        print("Örnek medya: \(media.description)")

        // Manifest sırası = galeri sırası; varlıkları da o sırada üretiriz ki
        // çıktıyı gözle tararken galeriyle aynı sırayı göresin.
        let entries = manifest.templates.filter { options.only == nil || $0.id == options.only }
        guard !entries.isEmpty else {
            print("hata: '\(options.only ?? "")' manifestte yok"); exit(1)
        }
        print("\(entries.count) şablon · \(options.width)px genişlik · dil \(options.language)\n")

        var totalBytes = 0
        var failures: [String] = []
        let start = Date()

        for (index, entry) in entries.enumerated() {
            let label = "[\(index + 1)/\(entries.count)] \(entry.id)"
            do {
                let bytes = try await render(entry: entry, options: options,
                                             media: media, work: work,
                                             thumbs: thumbsDirectory,
                                             previews: previewsDirectory)
                totalBytes += bytes
                print(String(format: "%@ — %.0f KB", label, Double(bytes) / 1024))
            } catch {
                failures.append(entry.id)
                print("\(label) — HATA: \(error)")
            }
        }

        print(String(format: "\nBitti: %d şablon, %.1f MB önizleme, %.0f sn",
                     entries.count - failures.count,
                     Double(totalBytes) / 1_048_576,
                     Date().timeIntervalSince(start)))
        if !failures.isEmpty {
            print("Başarısız: \(failures.joined(separator: ", "))")
            exit(1)
        }
    }

    /// Tek şablon: küçük çözünürlükte export → previews/<id>.mp4, aynı
    /// videodan bir kare → thumbs/<id>.jpg. Dönen değer önizlemenin boyutu.
    static func render(entry: TemplateManifest.Entry, options: Options,
                       media: MediaPool, work: URL,
                       thumbs: URL, previews: URL) async throws -> Int {
        // `templatePath` katalogla aynı sözleşme — manifest neyi gösteriyorsa onu okuruz.
        let templateURL = options.templatesDirectory
            .appendingPathComponent(entry.templatePath)
        var template = try JSONDecoder().decode(Template.self,
                                                from: Data(contentsOf: templateURL))
        try TemplateValidator.validate(template)

        // Vitrin çözünürlüğü. Düzen normalize koordinatlarda olduğu için kanvası
        // küçültmek görünümü birebir korur; fps'e DOKUNMUYORUZ — montaj süreleri
        // kareye snap ediliyor, fps değişimi sahne sınırlarını kaydırırdı.
        let scaled = Canvas(width: options.width,
                            height: even(options.width * template.canvas.height
                                         / template.canvas.width),
                            fps: template.canvas.fps)
        template.canvas = scaled

        var edits = UserEdits(textOverrides: template.defaultTexts(languageCode: options.language))
        var videos: [TemplateExporter.VideoInput] = []
        var photos: [Int: CGImage] = [:]
        // Her şablon farklı bir klipten başlar — yoksa tek slotlu şablonların
        // hepsi aynı görüntüyle çıkıyor ve galeri tek renk görünüyordu. Kaydırma
        // id'den DETERMİNİSTİK türetilir (Swift'in hashValue'su koşular arasında
        // değişir; aynı depo aynı varlıkları üretsin istiyoruz).
        // Klip sırası şablonun KATEGORİSİNE göre seçilir: yemek şablonu tepeden
        // tabak, emlak şehir/iç mekân, moda kumaş/portre alsın. Vitrin görseli
        // şablonun ne işe yaradığını anlatmanın en hızlı yolu; rastgele bir
        // manzara koyunca 127 kart birbirine benziyor.
        let order = media.order(for: template.category, templateID: entry.id)
        var videoIndex = 0, photoIndex = 0
        for slot in template.mediaSlots {
            if slot.allowsVideo {
                let url = media.clip(order[videoIndex % order.count])
                videos.append(.init(asset: AVURLAsset(url: url), slotIndex: slot.slot))
                edits.slots[slot.slot] = SlotAssignment(assetIdentifier: url.path, kind: .video)
                videoIndex += 1
            } else {
                photos[slot.slot] = media.photo(order[photoIndex % order.count])
                edits.slots[slot.slot] = SlotAssignment(assetIdentifier: "photo", kind: .photo)
                photoIndex += 1
            }
        }

        let master = work.appendingPathComponent("\(entry.id)-master.mp4")
        try? FileManager.default.removeItem(at: master)
        // Vitrin varlığı: filigran YOK (pazarlama görseli, kullanıcı çıktısı değil)
        // ve ses YOK — galeri önizlemeleri sessiz oynar, ses dosyayı büyütürdü.
        let request = TemplateExporter.Request(
            template: template,
            edits: edits,
            photos: photos,
            videos: videos,
            audio: nil,
            includeWatermark: false,
            workDirectory: work,
            outputURL: master)
        let rendered = try await TemplateExporter().export(request)

        // Poster karesi USTA kopyadan alınır (sıkıştırma artefaktı taşımasın).
        try writeThumbnail(from: rendered, to: thumbs.appendingPathComponent("\(entry.id).jpg"),
                           times: posterCandidates(template, edits: edits))

        // Exporter kullanıcının videosunu `HighestQuality` ile yazar — doğrusu o,
        // ama galeri döşemesi için 10 kat fazla. Vitrin kopyasını burada
        // hedef bitrate'e indiriyoruz (ürün export'una dokunmadan).
        let output = previews.appendingPathComponent("\(entry.id).mp4")
        try? FileManager.default.removeItem(at: output)
        try await Transcoder.compress(rendered, to: output, bitRate: options.bitRate)

        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        return (attributes[.size] as? Int) ?? 0
    }

    /// Poster karesi için aday zamanlar: METİN katmanlarının ekranda olduğu
    /// anlar.
    ///
    /// Sabit oran işe yaramıyor — baştaki kareler fade yüzünden siyah, montajda
    /// bir oran geçişin ortasına düşüp bulanık kare veriyor, `fast-cut` gibi
    /// şablonlarda ise metin yalnız ilk ve son sahnede olduğu için ortadan
    /// alınan kare şablonu hiç tanıtmıyor. "En net kareyi seç" de yetmedi:
    /// kalabalık bir sokak görüntüsü metinden daha çok kenar üretip kazanıyor.
    ///
    /// `flattenedLayersForRender` sahne offsetlerini uygulayıp mutlak zamanları
    /// verdiği için pencereler motorun gördüğüyle birebir aynı.
    /// Her aday, o anda ekranda olan metnin BELİRGİNLİĞİYLE ağırlıklandırılır
    /// (font boyutlarının toplamı). Yalnız netliğe bakmak yetmiyordu: alt
    /// köşedeki küçük "@kullanici" satırının kaldığı kare, ana başlığın
    /// göründüğü kareden net çıkıp posteri kazanabiliyor — şablonu tanıtan
    /// başlık posterde hiç görünmüyordu.
    static func posterCandidates(_ template: Template, edits: UserEdits) -> [(time: Double, weight: Double)] {
        let duration = template.totalDuration
        let layers = template.flattenedLayersForRender(edits: edits)
        var times: [Double] = []
        for layer in layers {
            guard case .text = layer.content else { continue }
            let window = layer.timing.window(templateDuration: duration)
            let span = window.end - window.start
            guard span > 0.2 else { continue }
            // Pencerenin geç kısmı: giriş animasyonu (fadeIn/daktilo) bitmiş olsun.
            times.append(window.start + span * 0.7)
            if span > 1.5 { times.append(window.start + span * 0.9) }
        }
        // Metinsiz şablon (ör. saf kolaj) — süreye yayılmış genel adaylar.
        if times.isEmpty {
            times = [0.3, 0.5, 0.7, 0.85].map { duration * $0 }
        }
        return times
            .map { min(max(0.1, $0), max(0.1, duration - 0.05)) }
            .map { (time: $0, weight: textProminence(layers, at: $0, duration: duration)) }
    }

    /// Verilen anda görünen metin katmanlarının font boyutları toplamı
    /// (kanvasa normalize). Metin yoksa 1 — ağırlık puanı sıfırlamasın.
    private static func textProminence(_ layers: [Layer], at time: Double,
                                       duration: Double) -> Double {
        var total = 0.0
        for layer in layers {
            guard case .text(let content) = layer.content else { continue }
            let window = layer.timing.window(templateDuration: duration)
            guard time >= window.start, time <= window.end else { continue }
            total += content.font.size
        }
        return total > 0 ? total : 1
    }

    /// Adaylardan en yüksek puanlıyı (netlik × metin belirginliği) yazar —
    /// bulanık geçiş karesini ve şablonu tanıtmayan kareyi birlikte eler.
    static func writeThumbnail(from video: URL, to url: URL,
                               times: [(time: Double, weight: Double)]) throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var best: (image: CGImage, score: Double)?
        for candidateTime in times {
            let time = CMTime(seconds: candidateTime.time, preferredTimescale: 600)
            guard let candidate = try? generator.copyCGImage(at: time, actualTime: nil) else {
                continue
            }
            let score = detail(candidate) * candidateTime.weight
            if best == nil || score > best!.score { best = (candidate, score) }
        }
        guard let image = best?.image else { throw CocoaError(.fileReadCorruptFile) }

        try? FileManager.default.removeItem(at: url)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        // Kalite 0.6 — uygulama posteri EN FAZLA 512 px'de gösteriyor
        // (`ThumbnailStore.maxPixelSize`), yani 540 px'lik bu dosya zaten
        // 1:1'de görünüyor ve daha yüksek kalite ekranda hiç fark etmiyor
        // (0.85 ile yan yana bakıldı). Karşılığında TÜM katalogun posteri
        // uygulama paketine sığıyor: 127 şablon × 2 dil ≈ 12 MB, 20 MB değil.
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    /// H.264 çift sayı boyut ister.
    static func even(_ value: Int) -> Int { value % 2 == 0 ? value : value + 1 }

    /// Karenin "netlik" puanı: küçültülmüş gri tonda komşu piksel farklarının
    /// toplamı. Bulanık geçiş kareleri ve yarı yazılmış metin düşük puan alır,
    /// yerleşimi oturmuş net kare kazanır.
    static func detail(_ image: CGImage) -> Double {
        let width = 96, height = 96 * image.height / max(1, image.width)
        guard height > 1,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return 0
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.bindMemory(to: UInt8.self,
                                                    capacity: width * height) else { return 0 }
        var total = 0.0
        for y in 1..<height {
            for x in 1..<width {
                let index = y * width + x
                let dx = Double(pixels[index]) - Double(pixels[index - 1])
                let dy = Double(pixels[index]) - Double(pixels[index - width])
                total += abs(dx) + abs(dy)
            }
        }
        return total / Double((width - 1) * (height - 1))
    }
}

// MARK: - Seçenekler

struct Options {
    /// Şablonların kaynak dili — bu dilin varlıkları klasör kökünde durur.
    static let sourceLanguage = "tr"

    var templatesDirectory: URL
    var samplesDirectory: URL
    var language = Options.sourceLanguage
    var width = 540
    /// Önizleme hedef bitrate'i (bit/sn). 540x960'ta ~900k gözle temiz, dosya küçük.
    var bitRate = 900_000
    var only: String?
    var makeSamples = false

    init(_ arguments: [String]) {
        // TemplateKit/ dizininden koşulduğu varsayılır (swift run oradan çalışır).
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent()
        templatesDirectory = root.appendingPathComponent("templates")
        // Örnek klipler ARTIK uygulama paketinde değil (kullanıcının videosuna
        // bizim örnek görüntümüz girmesin diye editör boş başlıyor); yalnız
        // vitrin varlıklarını üretmek için depoda duruyorlar.
        samplesDirectory = root.appendingPathComponent("tools/samples")

        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            let value = index + 1 < arguments.count ? arguments[index + 1] : nil
            switch flag {
            case "--only": only = value; index += 2
            case "--lang": language = value ?? language; index += 2
            case "--width": width = value.flatMap(Int.init) ?? width; index += 2
            case "--bitrate": bitRate = value.flatMap(Int.init) ?? bitRate; index += 2
            case "--templates": templatesDirectory = URL(fileURLWithPath: value ?? ""); index += 2
            case "--samples": samplesDirectory = URL(fileURLWithPath: value ?? ""); index += 2
            case "--make-samples": makeSamples = true; index += 1
            default:
                print("bilinmeyen argüman: \(flag)"); exit(2)
            }
        }
        width = Assets.even(width)
    }
}

// MARK: - Sıkıştırma

/// Render edilmiş videoyu hedef bitrate'e yeniden kodlar. AVAssetExportSession
/// preset seçtiriyor ama bitrate ayarlatmıyor; galeri önizlemesi için boyutu
/// kontrol etmek gerektiğinden reader/writer ile kendimiz geçiriyoruz.
enum Transcoder {
    static func compress(_ input: URL, to output: URL, bitRate: Int) async throws {
        let asset = AVURLAsset(url: input)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let size = try await track.load(.naturalSize)
        let frameRate = try await track.load(.nominalFrameRate)

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                // Döngü başa sararken hızlı seek edilebilsin diye sık anahtar kare.
                AVVideoMaxKeyFrameIntervalKey: Int(max(1, frameRate)),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadUnknown) }
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "templatekit.assets.transcode")
        await withCheckedContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    guard let buffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                    writerInput.append(buffer)
                }
            }
        }
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }
}

// MARK: - Örnek medya

/// Slotları dolduran örnek medya. Video slotlarına depodaki örnek klipler,
/// foto slotlarına aynı kliplerden alınmış birer kare gider.
struct MediaPool {
    private let clips: [URL]
    private let frames: [CGImage]
    let description: String

    init(samplesDirectory: URL) async throws {
        let found = (try? FileManager.default.contentsOfDirectory(
            at: samplesDirectory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "mp4" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        clips = found

        var extracted: [CGImage] = []
        for clip in found {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clip))
            generator.appliesPreferredTrackTransform = true
            if let image = try? generator.copyCGImage(
                at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil) {
                extracted.append(image)
            }
        }
        frames = extracted

        if found.isEmpty {
            description = "yok (\(samplesDirectory.path)) → gradyan yedeği"
        } else {
            description = "\(found.count) klip, \(extracted.count) kare"
        }
    }

    /// Şablon başına başlangıç kaydırması — id'nin deterministik toplamı.
    func offset(for templateID: String) -> Int {
        guard !clips.isEmpty else { return 0 }
        let sum = templateID.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return sum % clips.count
    }

    /// Kliplerin (0 tabanlı) tercih sırası: önce kategoriye yakışanlar, sonra
    /// kalanlar. Aynı kategorideki şablonlar aynı klibe saplanmasın diye liste
    /// şablon id'sine göre DETERMİNİSTİK olarak döndürülür.
    ///
    /// Sıra `sample-01…10` ile eşleşir:
    /// 0 sunset · 1 ocean · 2 forest · 3 night · 4 desert
    /// 5 city · 6 cafe · 7 plate · 8 studio · 9 fabric
    func order(for category: String, templateID: String) -> [Int] {
        guard !clips.isEmpty else { return [0] }
        // Klip TÜRLERİ dosya adından okunur ("sample-01-food.mp4" -> "food"),
        // sabit indeksten değil: `source/` klasörüne gerçek fotoğraf eklenince
        // sıralama kayıyor ve indeks tabanlı eşleştirme yanlış klibi seçiyordu.
        let kinds = clips.map { clip -> String in
            let parts = clip.deletingPathExtension().lastPathComponent.split(separator: "-")
            return parts.count >= 3 ? String(parts[2]) : ""
        }
        let wanted: [String]
        switch category {
        case "food":       wanted = ["food", "plate", "dessert", "pour", "hands", "cafe"]
        case "travel":     wanted = ["nature", "sunset", "ocean", "forest", "desert", "city"]
        case "realestate": wanted = ["room", "house", "city", "cafe"]
        case "fashion":    wanted = ["clothes", "shoes", "shop", "fabric", "texture"]
        // GÜZELLİK önce yüzsüz İNSAN VARLIĞI ister: manikür, saç, makyaj
        // fırçası. Eskiden burada `studio` (boş plato) vardı ve kategori
        // "kimsenin olmadığı bir stüdyo" gibi görünüyordu — satan kategoride
        // en pahalı hata buydu.
        case "beauty":     wanted = ["nails", "hair", "makeup", "salon", "spa"]
        case "fitness":    wanted = ["gym", "run", "yoga"]
        case "music":      wanted = ["music", "vinyl", "night", "city"]
        case "business":   wanted = ["workspace", "write", "shop", "cafe", "city"]
        case "education":  wanted = ["books", "write", "workspace", "cafe"]
        // promo = her işin indirim/kampanya duyurusu; NÖTR bir zemin ister.
        // Eskiden "food" başta geliyordu ve "Keten Gömlek ₺1.290" kartı bir
        // tabak etle çıkıyordu — vitrinde şablonun ne işe yaradığını yanlış
        // anlatıyor. Yemek promosyonu şablonları `food` kategorisinde.
        case "promo":      wanted = ["shop", "clothes", "plate", "texture", "fabric"]
        case "wedding":    wanted = ["flowers", "candle", "spa", "sunset"]
        case "holiday":    wanted = ["party", "candle", "flowers", "night", "sunset"]
        default:           wanted = []        // social / minimal: tümü
        }
        let available = wanted.flatMap { kind in
            kinds.enumerated().filter { $0.element == kind }.map(\.offset)
        }
        let rotation = available.isEmpty ? 0 : offset(for: templateID) % available.count
        let rotated = Array(available[rotation...] + available[..<rotation])
        // YAKIN PLAN dokular (kumaş/örgü/deri) yalnız İSTEYEN kategoriye gider;
        // yedek listesinin de SONUNA konur. Tam kadraj zemin olarak kullanılınca
        // kart "halı fotoğrafı" gibi görünüyor ve açık dokuda başlık okunmuyor
        // (katalogun ilk kartı bir kez böyle çıktı).
        let closeUp = ["texture", "fabric", "nails"]
        let rest = (0..<clips.count).filter { !available.contains($0) }
        let restMain = rest.filter { !closeUp.contains(kinds[$0]) }
        // Kaydırma yalnız yedeğin ANA bölümünde: tüm listeyi döndürmek yakın plan
        // dokuları bazı şablonlarda yine başa taşıyordu.
        let restRotation = restMain.isEmpty ? 0 : offset(for: templateID) % restMain.count
        let rotatedRest = Array(restMain[restRotation...] + restMain[..<restRotation])
        return rotated + rotatedRest + rest.filter { closeUp.contains(kinds[$0]) }
    }

    /// Aynı şablonda ardışık slotlar FARKLI klip alır (kolaj/geçiş görünsün).
    func clip(_ index: Int) -> URL {
        precondition(!clips.isEmpty, "video slotu var ama örnek klip yok — --samples ver")
        return clips[index % clips.count]
    }

    func photo(_ index: Int) -> CGImage {
        if frames.isEmpty { return MediaPool.gradient(index) }
        return frames[index % frames.count]
    }

    /// Örnek klip bulunamazsa (ör. yalnız TemplateKit'i klonlamışsan) yedek.
    static func gradient(_ index: Int, width: Int = 1080, height: Int = 1350) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let tints: [(CGFloat, CGFloat, CGFloat)] = [
            (0.96, 0.78, 0.52), (0.35, 0.55, 0.72), (0.45, 0.68, 0.52),
            (0.90, 0.55, 0.42), (0.58, 0.45, 0.70)
        ]
        let tint = tints[index % tints.count]
        let gradient = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: tint.0, green: tint.1, blue: tint.2, alpha: 1),
            CGColor(srgbRed: tint.0 * 0.5, green: tint.1 * 0.5, blue: tint.2 * 0.5, alpha: 1)
        ] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)),
                                   end: CGPoint(x: CGFloat(width), y: 0), options: [])
        return context.makeImage()!
    }
}
