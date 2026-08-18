#!/usr/bin/env swift
// Aday vitrin karelerinde YÜZ arar (Vision).
//
// NEDEN: `CREDITS.md` kuralı "tanınabilir insan vitrine girmez" diyor —
// bu hukuki bir refleks (model izni olmayan kişi ticari vitrinde kullanılamaz).
// Kuralı gözle uygulamak 60 karede güvenilir değil; bir kare kaçarsa 127
// posterin içine girip dağıtılıyor. Vision yüzü bulup söylüyor, karar bende.
//
// YÜZSÜZ insan varlığı (arkadan baş, omuz üstü, çalışan eller) KABUL — vitrinin
// aradığı tam olarak o. Bu betik "insan var mı" değil, "YÜZ var mı" sorar.
//
//     swift tools/detect-faces.swift tools/samples/candidates
//
// Çıktı: her dosya için yüz sayısı ve en büyük yüzün kadraja oranı.
// Oran küçükse (uzakta, arkası dönük, profil) karar gözle verilir; bu yüzden
// betik dosya SİLMEZ, yalnız raporlar.

import Foundation
import Vision
import CoreImage

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("kullanım: swift tools/detect-faces.swift <klasör>")
    exit(2)
}

let directory = URL(fileURLWithPath: arguments[1])
let files = ((try? FileManager.default.contentsOfDirectory(
    at: directory, includingPropertiesForKeys: nil)) ?? [])
    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var flagged: [String] = []

for file in files {
    guard let image = CIImage(contentsOf: file) else {
        print("\(file.lastPathComponent): OKUNAMADI")
        continue
    }
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    do {
        try handler.perform([request])
    } catch {
        print("\(file.lastPathComponent): tarama hatası \(error)")
        continue
    }
    let faces = request.results ?? []
    guard !faces.isEmpty else { continue }
    // Kadrajın yüzdesi olarak en büyük yüz: boundingBox normalize (0-1).
    let largest = faces.map { $0.boundingBox.width * $0.boundingBox.height }.max() ?? 0
    let percent = largest * 100
    flagged.append(file.lastPathComponent)
    let mark = percent >= 0.5 ? "YÜZ" : "yüz?"
    print(String(format: "%@ %@ — %d yüz, en büyüğü kadrajın %%%.2f'i",
                 mark, file.lastPathComponent, faces.count, percent))
}

print("\n\(files.count) kare tarandı, \(flagged.count) tanesinde yüz bulundu.")
if !flagged.isEmpty {
    print("Bunlar ACCEPTED.txt'e YAZILMAZ (küçük oranlılar gözle bakılır):")
    print(flagged.joined(separator: "\n"))
}
