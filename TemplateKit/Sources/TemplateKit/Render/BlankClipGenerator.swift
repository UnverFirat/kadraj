#if canImport(AVFoundation)
import Foundation
import AVFoundation
import CoreVideo

/// Foto-only şablonların export'u için gereken siyah taban klibini üretir
/// (CoreAnimationTool en az bir video track ister, bkz. render-engine.md).
/// Uygulama ilk export öncesi bir kez üretip cache'ler — bundle'a mp4 koymaya
/// gerek kalmaz, kanvas boyutu değişirse de yeniden üretilebilir.
public enum BlankClipGenerator {

    public static func generate(at url: URL,
                                size: CGSize = CGSize(width: 1080, height: 1920),
                                duration: Double = 1.0,
                                fps: Int32 = 30) async throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])
        writer.add(input)

        guard writer.startWriting() else {
            throw TemplateExportError.failed(underlying: writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw TemplateExportError.failed(underlying: writer.error)
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else {
            throw TemplateExportError.failed(underlying: nil)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            // BGRA sıfırları = opak olmayan siyah; H.264'te alfa olmadığı için
            // sonuç düz siyah karedir.
            memset(base, 0, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let frameCount = max(2, Int(duration * Double(fps)))
        var frame = 0
        while frame < frameCount {
            if input.isReadyForMoreMediaData {
                adaptor.append(buffer,
                               withPresentationTime: CMTime(value: CMTimeValue(frame),
                                                            timescale: fps))
                frame += 1
            } else {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw TemplateExportError.failed(underlying: writer.error)
        }
    }
}
#endif
