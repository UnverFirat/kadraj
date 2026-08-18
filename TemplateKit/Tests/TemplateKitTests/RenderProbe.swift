#if canImport(AVFoundation) && canImport(CoreImage)
import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
@testable import TemplateKit

/// Render çıktısını ÖLÇEN yardımcılar.
///
/// Motorun davranışını (hız, kadraj, trim, metin stili, yeniden kadrajlama)
/// modeli okuyarak doğrulamak mümkün değil — hepsi kompozisyon zaman haritasına
/// ya da piksele yazılıyor. Bu yüzden testler gerçekten render alıp KAREYE
/// bakıyor; ölçüm ve ölçüm klibi üretimi tek yerde dursun diye burada.
enum RenderProbe {

    /// Karenin ortalama gri değeri (0-1). Tüm kare 1x1'e indirilerek okunur.
    static func meanGray(of url: URL, at seconds: Double,
                         exactFrame: Bool = true) async throws -> Double {
        try await ProbeClip.gray(of: url, at: seconds, region: .full, exactFrame: exactFrame)
    }
}

/// Ölçüm klibi üretici + bölge okuyucu.
enum ProbeClip {

    /// Karenin hangi bölgesinin okunacağı.
    enum Region {
        /// Tüm kare (ortalama).
        case full
        /// Ortadaki üçte bir kutu.
        case center
        /// Sol kenar şeridi (dolgu/letterbox kontrolü).
        case leftEdge

        func rect(in size: CGSize) -> CGRect {
            switch self {
            case .full:
                return CGRect(origin: .zero, size: size)
            case .center:
                return CGRect(x: size.width / 3, y: size.height / 3,
                              width: size.width / 3, height: size.height / 3)
            case .leftEdge:
                return CGRect(x: 0, y: size.height / 3,
                              width: max(size.width * 0.08, 1), height: size.height / 3)
            }
        }
    }

    /// Videonun `seconds` anındaki karesinin verilen bölgesinin ortalama gri
    /// değeri (0-1).
    static func gray(of url: URL, at seconds: Double, region: Region = .full,
                     exactFrame: Bool = true) async throws -> Double {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        if exactFrame {
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
        }
        let image = try await generator.image(
            at: CMTime(seconds: seconds, preferredTimescale: 600)).image

        let full = CGSize(width: image.width, height: image.height)
        let crop = region.rect(in: full).integral
        let source = image.cropping(to: crop) ?? image

        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(data: &pixel, width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw TemplateExportError.failed(underlying: nil) }
        // Bölgenin tamamını 1x1'e indirmek = ortalaması.
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Double(pixel[0]) / 255
    }

    /// Kare kare piksel üreten yardımcıyla H.264 klip yazar.
    ///
    /// `value(frame, x, y, width, height)` gri değeri döner; koordinatlar
    /// **y AŞAĞI** (0 = üst satır).
    static func write(at url: URL, size: CGSize, seconds: Double, fps: Int,
                      value: (Int, Int, Int, Int, Int) -> UInt8) async throws {
        let width = Int(size.width), height = Int(size.height)
        let timescale = Int32(fps)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ])
        writer.add(input)
        guard writer.startWriting(), let pool = adaptor.pixelBufferPool else {
            throw TemplateExportError.failed(underlying: writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        let frames = Int(seconds * Double(fps))
        var frame = 0
        while frame < frames {
            guard input.isReadyForMoreMediaData else {
                try await Task.sleep(nanoseconds: 5_000_000)
                continue
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw TemplateExportError.failed(underlying: nil) }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                // BGRA: renk kanalları değeri taşır, alfa OPAK kalır. (Tümünü
                // birden memset etmek alfayı da griye çekiyor ve premultiply
                // varsayan CoreImage hattında kareyi soluklaştırıyor.)
                let rows = CVPixelBufferGetBytesPerRow(buffer)
                let pointer = base.assumingMemoryBound(to: UInt8.self)
                for y in 0..<height {
                    let row = pointer + y * rows
                    for x in 0..<width {
                        let v = value(frame, x, y, width, height)
                        let pixel = row + x * 4
                        pixel[0] = v; pixel[1] = v; pixel[2] = v; pixel[3] = 255
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame),
                                                               timescale: timescale))
            frame += 1
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw TemplateExportError.failed(underlying: writer.error)
        }
    }
}
#endif
