import XCTest
@testable import TemplateKit

final class MusicLibraryTests: XCTestCase {

    /// Depodaki şablon klasörü (paket kaynağı değil — gerçek katalog).
    private var templatesDirectory: URL {
        URL(fileURLWithPath: #filePath)            // .../Tests/TemplateKitTests/MusicTests.swift
            .deletingLastPathComponent()           // TemplateKitTests
            .deletingLastPathComponent()           // Tests
            .deletingLastPathComponent()           // TemplateKit
            .deletingLastPathComponent()           // repo kökü
            .appendingPathComponent("templates")
    }

    func testEveryTemplateDefaultTrackExists() throws {
        let files = try FileManager.default.contentsOfDirectory(at: templatesDirectory,
                                                                includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertFalse(files.isEmpty, "şablon klasörü bulunamadı: \(templatesDirectory.path)")

        for file in files {
            let template = try JSONDecoder().decode(Template.self, from: Data(contentsOf: file))
            guard let trackID = template.audio?.defaultTrackId else { continue }
            XCTAssertNotNil(MusicLibrary.track(id: trackID),
                            "\(template.id) tanınmayan parça referanslıyor: \(trackID)")
        }
    }

    func testTrackIDsAreUnique() {
        let ids = MusicLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPatternsAreSixteenSteps() {
        for track in MusicLibrary.all {
            let patterns = [track.score.bassPattern, track.score.leadPattern,
                            track.score.drums.kick, track.score.drums.snare,
                            track.score.drums.hat]
            for pattern in patterns {
                XCTAssertEqual(pattern.count, 16, "\(track.id): desen 16 adım olmalı — '\(pattern)'")
            }
        }
    }

    func testScaleDegreesWrapAcrossOctaves() {
        let score = MusicScore(bpm: 120, rootMIDI: 60, scale: .major,
                               progression: [0], texture: .pad)
        XCTAssertEqual(score.midi(degree: 0), 60)
        XCTAssertEqual(score.midi(degree: 4), 67)        // 5. derece = Sol
        XCTAssertEqual(score.midi(degree: 7), 72)        // bir oktav üstü kök
        XCTAssertEqual(score.midi(degree: -1), 59)       // negatif derece de sarmalı
        XCTAssertEqual(MusicScore.frequency(midi: 69), 440, accuracy: 0.0001)
    }

    func testPatternParsingExtendsWithDash() {
        let hits = AudioSynth.parse("x---............")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].step, 0)
        XCTAssertEqual(hits[0].length, 4)
    }

    func testRenderIsDeterministicAndAudible() {
        let track = try! XCTUnwrap(MusicLibrary.track(id: "upbeat-01"))
        let a = AudioSynth.render(score: track.score, duration: 2, seed: 42)
        let b = AudioSynth.render(score: track.score, duration: 2, seed: 42)
        XCTAssertEqual(a.count, Int(2 * AudioSynth.sampleRate))
        XCTAssertEqual(a.left, b.left, "aynı seed farklı örnekler üretmemeli")
        XCTAssertEqual(a.right, b.right)

        let peak = (a.left + a.right).map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(peak, 0.5, "master normalizasyonu sonrası sessiz olmamalı")
        XCTAssertLessThanOrEqual(peak, 1.0, "kırpma sınırını aşmamalı")

        // Stereo gerçek olmalı — kanallar birebir aynıysa yerleşim çalışmıyor.
        let difference = zip(a.left, a.right).reduce(0.0) { $0 + Double(abs($1.0 - $1.1)) }
        XCTAssertGreaterThan(difference / Double(a.count), 0.001, "kanallar özdeş (mono)")
    }

    func testEveryTrackProducesSound() {
        for track in MusicLibrary.all {
            let buffer = AudioSynth.render(score: track.score, duration: 1.5)
            let rms = (buffer.left.reduce(0) { $0 + Double($1 * $1) }
                       / Double(buffer.count)).squareRoot()
            XCTAssertGreaterThan(rms, 0.02, "\(track.id) neredeyse sessiz (rms \(rms))")
        }
    }

    func testWavContainerIsWellFormed() {
        let buffer = AudioSynth.render(score: MusicLibrary.all[0].score, duration: 0.5)
        let data = AudioSynth.wavData(buffer)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        // 16-bit stereo: örnek başına 4 bayt + 44 baytlık başlık.
        XCTAssertEqual(data.count, 44 + buffer.count * 4)
    }

    func testChordVoicingStaysInMidRangeAndAddsSeventh() {
        let score = MusicScore(bpm: 90, rootMIDI: 60, scale: .minor,
                               progression: [0], texture: .pad)
        let chord = score.chordVoicing(degree: 0)
        XCTAssertEqual(chord.count, 4, "7'li akor bekleniyor")
        for note in chord {
            XCTAssertTrue((60...79).contains(note),
                          "akor sesleri orta bölgede kalmalı (pes üçlü çamur yapar): \(note)")
        }
    }

    func testMaterializeWritesAndReusesFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("music-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try MusicLibrary.materialize(trackID: "calm-01", duration: 1, in: directory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let modified = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        let again = try MusicLibrary.materialize(trackID: "calm-01", duration: 1, in: directory)
        XCTAssertEqual(url, again)
        let modifiedAgain = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(modified, modifiedAgain, "cache'lenmiş dosya yeniden üretilmemeli")

        XCTAssertThrowsError(try MusicLibrary.materialize(trackID: "yok-01", duration: 1,
                                                          in: directory))
    }
}
