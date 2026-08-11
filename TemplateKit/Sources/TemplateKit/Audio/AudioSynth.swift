import Foundation

/// `MusicScore` -> stereo PCM -> WAV. Saf Foundation (AVFoundation gerekmez),
/// böylece testlerde ve macOS CLI'da da koşar.
///
/// Küçük ama TAM bir synth: filtreli osilatörler (ADSR + zarf modülasyonlu
/// alçak geçiren), ayrı davul sentezi, reverb ve tempoya kilitli delay,
/// stereo yerleşim, groove/velocity insanileştirmesi ve master zinciri
/// (kompresör + limiter). İlk sürüm filtresiz saf sinüs toplamıydı ve "alarm"
/// gibi tınlıyordu — kaliteyi getiren şey filtre + zarf + mekân + dinamik.
public enum AudioSynth {

    public static let sampleRate: Double = 44100

    /// Sentez motorunun sürümü. Tını değişince ARTIR — `MusicLibrary` cache
    /// dosya adında kullanır, böylece eski üretimler otomatik geçersizleşir.
    public static let version = 2

    /// İki kanallı ses tamponu (kanallar ayrı — stereo yerleşim gerçek).
    public struct StereoBuffer {
        public var left: [Float]
        public var right: [Float]
        public var count: Int { left.count }

        public init(count: Int) {
            left = [Float](repeating: 0, count: count)
            right = [Float](repeating: 0, count: count)
        }
    }

    // MARK: - Genel API

    /// Skoru `duration` saniyelik stereo PCM'e (-1...1) render eder.
    /// Aynı skor + aynı seed her zaman birebir aynı örnekleri verir.
    public static func render(score: MusicScore, duration: Double,
                              seed: UInt64 = 0x5EED) -> StereoBuffer {
        let total = max(1, Int(duration * sampleRate))
        var dry = StereoBuffer(count: total)
        var reverbSend = [Float](repeating: 0, count: total)
        var delaySend = [Float](repeating: 0, count: total)
        var rng = LCG(seed: seed)

        let stepDuration = score.barDuration / 16
        let bassHits = parse(score.bassPattern)
        let leadHits = parse(score.leadPattern)
        let kickHits = parse(score.drums.kick)
        let snareHits = parse(score.drums.snare)
        let hatHits = parse(score.drums.hat)
        let space = score.space

        var bar = 0
        while Double(bar) * score.barDuration < duration {
            let barStart = Double(bar) * score.barDuration
            let degree = score.progression[bar % score.progression.count]
            let chord = score.chordVoicing(degree: degree)

            /// Adımın zamanı: swing + küçük insani sapma (grid'e yapışık
            /// ritim "makine" gibi duyulur).
            func stepTime(_ step: Int) -> Double {
                let swing = step % 2 == 1 ? score.swing * stepDuration * 0.5 : 0
                return barStart + Double(step) * stepDuration + swing
                    + rng.nextBipolar() * 0.004
            }
            /// Vuruş yerine göre şiddet — 1. ve 3. vuruş güçlü, aralar zayıf.
            func velocity(_ step: Int) -> Double {
                let base: Double
                switch step % 16 {
                case 0: base = 1.0
                case 8: base = 0.92
                case 4, 12: base = 0.85
                default: base = step % 2 == 0 ? 0.75 : 0.62
                }
                return min(1, base + rng.nextBipolar() * 0.06)
            }

            // --- Akor katmanı ---
            switch score.texture {
            case .pad:
                // Tüm barı kaplayan, yavaş açılan ped; sesler stereo yayılır.
                for (index, note) in chord.enumerated() {
                    let pan = -0.45 + 0.9 * Double(index) / Double(max(1, chord.count - 1))
                    play(note: note, at: barStart, length: score.barDuration * 0.98,
                         patch: .pad(brightness: score.brightness), velocity: 0.55,
                         pan: pan, level: 0.17, reverb: 0.55 * space, delay: 0,
                         dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
                    // Üst seslerin bir oktav üstünde kısık parıltı katmanı —
                    // ped tek başına fazla "kapalı"/donuk kalıyor.
                    if index >= chord.count - 2 {
                        play(note: note + 12, at: barStart + 0.08,
                             length: score.barDuration * 0.8,
                             patch: .pad(brightness: min(1, score.brightness + 0.25)),
                             velocity: 0.3, pan: -pan, level: 0.06,
                             reverb: 0.7 * space, delay: 0,
                             dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
                    }
                }
            case .keys:
                // Elektrik piyano: 1. ve 3. vuruşta akor (yarım bar).
                for half in 0..<2 {
                    for (index, note) in chord.enumerated() {
                        let pan = -0.3 + 0.6 * Double(index) / Double(max(1, chord.count - 1))
                        play(note: note, at: barStart + Double(half) * score.barDuration / 2,
                             length: score.barDuration * 0.42,
                             patch: .keys(brightness: score.brightness),
                             velocity: half == 0 ? 0.85 : 0.7,
                             pan: pan, level: 0.24, reverb: 0.35 * space,
                             delay: 0.08 * space,
                             dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
                    }
                }
            case .pluck:
                // Arpej: akor sesleri 8'liklerde sırayla, yukarı-aşağı.
                let sequence = chord + chord.dropLast().reversed()
                for (index, note) in sequence.enumerated() where index < 8 {
                    play(note: note, at: stepTime(index * 2),
                         length: stepDuration * 1.8,
                         patch: .pluck(brightness: score.brightness),
                         velocity: velocity(index * 2),
                         pan: -0.45 + 0.9 * Double(index % 4) / 3,
                         level: 0.26, reverb: 0.4 * space, delay: 0.12 * space,
                         dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
                }
            case .none:
                break
            }

            // --- Bas ---
            for hit in bassHits {
                var note = score.midi(degree: degree)
                while note >= 48 { note -= 12 }      // bas bölgesi: 36-47
                while note < 36 { note += 12 }
                play(note: note, at: stepTime(hit.step),
                     length: Double(hit.length) * stepDuration * 0.9,
                     patch: .bass(brightness: score.brightness),
                     velocity: velocity(hit.step), pan: 0,
                     level: 0.27, reverb: 0.05 * space, delay: 0,
                     dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
            }

            // --- Melodi ---
            for hit in leadHits {
                guard let value = hit.char.wholeNumberValue else { continue }
                var note = score.midi(degree: degree + value, octave: score.leadOctave)
                while note > 86 { note -= 12 }
                while note < 67 { note += 12 }
                play(note: note, at: stepTime(hit.step),
                     length: Double(hit.length) * stepDuration * 0.85,
                     patch: .lead(brightness: score.brightness),
                     velocity: velocity(hit.step) * 0.9, pan: 0.12,
                     level: 0.22, reverb: 0.45 * space, delay: 0.3 * space,
                     dry: &dry, reverbSend: &reverbSend, delaySend: &delaySend)
            }

            // --- Davul ---
            let level = score.drums.level
            if level > 0 {
                for hit in kickHits {
                    addKick(&dry, at: stepTime(hit.step),
                            amplitude: 0.42 * level * velocity(hit.step), rng: &rng)
                }
                for hit in snareHits {
                    addSnare(&dry, reverbSend: &reverbSend, at: stepTime(hit.step),
                             amplitude: 0.38 * level * velocity(hit.step),
                             space: space, rng: &rng)
                }
                for hit in hatHits {
                    let open = hit.char == "o"
                    addHat(&dry, at: stepTime(hit.step),
                           amplitude: (open ? 0.24 : 0.18) * level * velocity(hit.step),
                           decay: open ? 0.18 : 0.035, rng: &rng)
                }
            }

            bar += 1
        }

        // --- Efekt busları ---
        let delayTime = (60 / score.bpm) * 0.75      // noktalı 8'lik
        applyDelay(delaySend, into: &dry, time: delayTime, feedback: 0.32)
        applyReverb(reverbSend, into: &dry, damping: 0.28 + 0.3 * (1 - score.brightness))
        master(&dry)
        return dry
    }

    /// Stereo tamponu 16-bit WAV konteynerine yazar (AVAsset okuyabilir).
    public static func wavData(_ buffer: StereoBuffer,
                               sampleRate: Double = AudioSynth.sampleRate) -> Data {
        let channels = 2, bitsPerSample = 16
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = buffer.count * blockAlign

        var data = Data(capacity: 44 + dataSize)
        func ascii(_ s: String) { data.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: Int) { var le = UInt32(v).littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        func u16(_ v: Int) { var le = UInt16(v).littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }

        ascii("RIFF"); u32(36 + dataSize); ascii("WAVE")
        ascii("fmt "); u32(16); u16(1); u16(channels)
        u32(Int(sampleRate)); u32(Int(sampleRate) * blockAlign); u16(blockAlign); u16(bitsPerSample)
        ascii("data"); u32(dataSize)

        var pcm = [UInt8]()
        pcm.reserveCapacity(dataSize)
        for index in 0..<buffer.count {
            for sample in [buffer.left[index], buffer.right[index]] {
                let value = Int16(max(-1, min(1, sample)) * 32767)
                pcm.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Array($0) })
            }
        }
        data.append(contentsOf: pcm)
        return data
    }

    // MARK: - Synth sesi (patch + zarf + filtre)

    /// Bir enstrümanın tınısı. Kaliteyi belirleyen üç şey: harmonik içerik,
    /// zarflar (ADSR) ve filtrenin zarfla açılıp kapanması.
    struct Patch {
        /// Harmonik ağırlıkları (1. harmonik = temel frekans).
        var partials: [Double]
        var attack: Double
        var decay: Double
        var sustain: Double
        var release: Double
        /// Filtre kesim frekansı (Hz) ve zarfla eklenen miktar.
        var cutoff: Double
        var cutoffEnvelope: Double
        var cutoffDecay: Double
        var resonance: Double
        /// Filtre kutup sayısı: 4 = 24 dB/okt (koyu, ped), 2 = 12 dB/okt (açık).
        /// Her şeyi 24 dB ile filtrelemek mixi boğuyordu (2 kHz üstü yok oluyordu).
        var poles: Int
        /// İkinci osilatörün sent cinsinden detune'u (0 = tek osilatör).
        var detune: Double
        /// Bir oktav alttan sinüs desteği (bas için gövde).
        var subLevel: Double
        /// Hafif doyum (harmonik zenginlik).
        var drive: Double

        static func pad(brightness: Double) -> Patch {
            Patch(partials: [1, 0.55, 0.3, 0.14, 0.07],
                  attack: 0.45, decay: 1.2, sustain: 0.75, release: 0.9,
                  cutoff: 1400 + 3000 * brightness, cutoffEnvelope: 900,
                  cutoffDecay: 2.5, resonance: 0.7, poles: 4,
                  detune: 7, subLevel: 0, drive: 0.1)
        }

        static func keys(brightness: Double) -> Patch {
            // Elektrik piyano: güçlü 1. + 3. harmonik, hızlı atak, uzun kuyruk.
            Patch(partials: [1, 0.22, 0.42, 0.12, 0.16, 0.07, 0.04],
                  attack: 0.006, decay: 0.9, sustain: 0.28, release: 0.45,
                  cutoff: 1400 + 4200 * brightness, cutoffEnvelope: 2600,
                  cutoffDecay: 0.5, resonance: 0.8, poles: 2,
                  detune: 4, subLevel: 0.08, drive: 0.18)
        }

        static func pluck(brightness: Double) -> Patch {
            Patch(partials: [1, 0.5, 0.32, 0.2, 0.12, 0.08, 0.05],
                  attack: 0.003, decay: 0.55, sustain: 0.12, release: 0.35,
                  cutoff: 1600 + 5200 * brightness, cutoffEnvelope: 3400,
                  cutoffDecay: 0.28, resonance: 1.0, poles: 2,
                  detune: 5, subLevel: 0, drive: 0.15)
        }

        static func bass(brightness: Double) -> Patch {
            // Sub kısıldı ve kesim yükseldi: bas duyulsun ama mixi yutmasın.
            Patch(partials: [1, 0.45, 0.24, 0.12, 0.06],
                  attack: 0.008, decay: 0.5, sustain: 0.5, release: 0.18,
                  cutoff: 320 + 900 * brightness, cutoffEnvelope: 900,
                  cutoffDecay: 0.2, resonance: 1.1, poles: 2,
                  detune: 0, subLevel: 0.18, drive: 0.25)
        }

        static func lead(brightness: Double) -> Patch {
            Patch(partials: [1, 0.32, 0.18, 0.09, 0.05, 0.03],
                  attack: 0.012, decay: 0.6, sustain: 0.4, release: 0.4,
                  cutoff: 1800 + 5000 * brightness, cutoffEnvelope: 2200,
                  cutoffDecay: 0.35, resonance: 0.9, poles: 2,
                  detune: 9, subLevel: 0, drive: 0.12)
        }
    }

    /// Tek nota: iki (detune'lu) osilatör + alçak geçiren filtre + ADSR,
    /// stereo yerleşim ve efekt gönderileriyle tamponlara yazılır.
    private static func play(note: Int, at start: Double, length: Double,
                             patch: Patch, velocity: Double, pan: Double,
                             level: Double, reverb: Double, delay: Double,
                             dry: inout StereoBuffer,
                             reverbSend: inout [Float],
                             delaySend: inout [Float]) {
        let startSample = Int(start * sampleRate)
        guard startSample >= 0, startSample < dry.count, length > 0 else { return }
        let sustainSamples = Int(length * sampleRate)
        let releaseSamples = Int(patch.release * sampleRate)
        let count = min(sustainSamples + releaseSamples, dry.count - startSample)
        guard count > 0 else { return }

        let frequency = MusicScore.frequency(midi: note)
        // Yüksek notada üst harmonikler nyquist'i aşmasın (aliasing = "ucuz" ses).
        let partials = patch.partials.enumerated().filter {
            frequency * Double($0.offset + 1) < sampleRate * 0.45
        }
        guard !partials.isEmpty else { return }

        var phases = [Double](repeating: 0, count: partials.count)
        var detunePhases = phases
        var subPhase = 0.0
        let detuneRatio = pow(2, patch.detune / 1200)

        var filter = SVF()
        let attackSamples = max(1, Int(patch.attack * sampleRate))
        let decaySamples = max(1, Int(patch.decay * sampleRate))
        let leftGain = Float(cos((pan + 1) * .pi / 4))     // eşit güçlü panning
        let rightGain = Float(sin((pan + 1) * .pi / 4))

        for i in 0..<count {
            let t = Double(i) / sampleRate

            // Genlik zarfı (ADSR).
            var envelope: Double
            if i < attackSamples {
                envelope = Double(i) / Double(attackSamples)
            } else if i < attackSamples + decaySamples {
                let progress = Double(i - attackSamples) / Double(decaySamples)
                envelope = 1 - (1 - patch.sustain) * progress
            } else {
                envelope = patch.sustain
            }
            if i >= sustainSamples {
                envelope *= exp(-Double(i - sustainSamples) / sampleRate / patch.release * 3)
            }
            envelope *= velocity
            // Nota penceresi kesilirken tık olmasın (release tam sıfıra inmez).
            let remaining = Double(count - i) / sampleRate
            if remaining < 0.012 { envelope *= remaining / 0.012 }

            // Osilatörler.
            var sample = 0.0
            for (index, partial) in partials.enumerated() {
                let increment = frequency * Double(partial.offset + 1) / sampleRate
                phases[index] += increment
                sample += partial.element * sine(phases[index])
                if patch.detune > 0 {
                    detunePhases[index] += increment * detuneRatio
                    sample += partial.element * 0.7 * sine(detunePhases[index])
                }
            }
            if patch.subLevel > 0 {
                subPhase += frequency / 2 / sampleRate
                sample += patch.subLevel * sine(subPhase)
            }
            sample *= 0.35

            // Zarf modülasyonlu alçak geçiren filtre — "canlı" tınının kaynağı.
            let cutoff = patch.cutoff + patch.cutoffEnvelope * exp(-t / patch.cutoffDecay)
            sample = filter.process(sample, cutoff: cutoff, resonance: patch.resonance,
                                    poles: patch.poles)

            if patch.drive > 0 {
                sample = tanh(sample * (1 + patch.drive * 3)) / (1 + patch.drive)
            }
            let value = sample * envelope * level
            let index = startSample + i
            dry.left[index] += Float(value) * leftGain
            dry.right[index] += Float(value) * rightGain
            if reverb > 0 { reverbSend[index] += Float(value * reverb) }
            if delay > 0 { delaySend[index] += Float(value * delay) }
        }
    }

    // MARK: - Davul

    private static func addKick(_ buffer: inout StereoBuffer, at start: Double,
                                amplitude: Double, rng: inout LCG) {
        let startSample = Int(start * sampleRate)
        guard startSample >= 0, startSample < buffer.count else { return }
        let count = min(Int(0.35 * sampleRate), buffer.count - startSample)
        var phase = 0.0, beaterPhase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Perde zarfı: 132 Hz -> 50 Hz. Gövde zarfı KISA tutuldu; uzun kuyruk
            // mixin tüm alt bölgesini yutuyordu (ölçümde %74 enerji <100 Hz).
            let frequency = 50 + 82 * exp(-t / 0.026)
            phase += frequency / sampleRate
            var value = sine(phase) * exp(-t / 0.105)
            // Tokmak sesi (~900 Hz) + tık: telefon hoparlöründe kick'i duyulur yapar.
            beaterPhase += 900 / sampleRate
            value += sine(beaterPhase) * 0.22 * exp(-t / 0.012)
            if t < 0.004 { value += rng.nextBipolar() * 0.3 * (1 - t / 0.004) }
            value = tanh(value * 1.6) * 0.7
            let sample = Float(value * amplitude)
            buffer.left[startSample + i] += sample
            buffer.right[startSample + i] += sample
        }
    }

    private static func addSnare(_ buffer: inout StereoBuffer,
                                 reverbSend: inout [Float], at start: Double,
                                 amplitude: Double, space: Double, rng: inout LCG) {
        let startSample = Int(start * sampleRate)
        guard startSample >= 0, startSample < buffer.count, amplitude > 0 else { return }
        let count = min(Int(0.35 * sampleRate), buffer.count - startSample)
        var previous = 0.0, lowpass = 0.0
        var bodyPhase1 = 0.0, bodyPhase2 = 0.0
        let lowpassCoefficient = 1 - exp(-2 * Double.pi * 7500 / sampleRate)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let noise = rng.nextBipolar()
            // Gürültü yüksek geçirenden geçer (tiz "ss") ama 7.5 kHz'de
            // sınırlanır; gövde iki tonlu.
            let raw = noise - previous
            previous = noise
            lowpass += (raw - lowpass) * lowpassCoefficient
            let bright = lowpass
            bodyPhase1 += 185 / sampleRate
            bodyPhase2 += 268 / sampleRate
            let body = (sine(bodyPhase1) * 0.6 + sine(bodyPhase2) * 0.4) * exp(-t / 0.045)
            let value = (bright * 0.55 * exp(-t / 0.085) + body * 0.5) * amplitude
            let sample = Float(value)
            buffer.left[startSample + i] += sample * 0.95
            buffer.right[startSample + i] += sample
            reverbSend[startSample + i] += Float(value * 0.35 * space)
        }
    }

    private static func addHat(_ buffer: inout StereoBuffer, at start: Double,
                               amplitude: Double, decay: Double, rng: inout LCG) {
        let startSample = Int(start * sampleRate)
        guard startSample >= 0, startSample < buffer.count, amplitude > 0 else { return }
        let count = min(Int(decay * 5 * sampleRate), buffer.count - startSample)
        var previous = 0.0, lowpass = 0.0
        // Gürültü hem yüksek geçirenden (tiz) hem 9 kHz alçak geçirenden geçer:
        // bant sınırlaması olmadan hat, nyquist'e kadar tıslıyor ve "ucuz"
        // duyuluyordu (ölçümde 12 kHz üstü mixin %13'ü).
        let lowpassCoefficient = 1 - exp(-2 * Double.pi * 7000 / sampleRate)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let noise = rng.nextBipolar()
            let bright = noise - previous
            previous = noise
            lowpass += (bright - lowpass) * lowpassCoefficient
            let value = lowpass * amplitude * exp(-t / decay)
            buffer.left[startSample + i] += Float(value * 0.75)
            buffer.right[startSample + i] += Float(value)
        }
    }

    // MARK: - Efektler

    /// Tempoya kilitli stereo delay (ping-pong): melodiye derinlik verir.
    private static func applyDelay(_ send: [Float], into buffer: inout StereoBuffer,
                                   time: Double, feedback: Double) {
        let delaySamples = Int(time * sampleRate)
        guard delaySamples > 0, delaySamples < buffer.count else { return }
        var line = [Float](repeating: 0, count: buffer.count)
        for i in delaySamples..<buffer.count {
            line[i] = send[i - delaySamples] + line[i - delaySamples] * Float(feedback)
        }
        for i in 0..<buffer.count {
            // Tek/çift tekrarları karşı kanala at (ping-pong hissi).
            buffer.left[i] += line[i] * 0.55
            buffer.right[i] += line[i] * 0.35
        }
    }

    /// Freeverb tarzı reverb: 4 tarak + 2 allpass, kanallar arası kaydırmayla
    /// stereo. Mekân hissi olmadan sentez "kuru ve ucuz" duyuluyor.
    private static func applyReverb(_ send: [Float], into buffer: inout StereoBuffer,
                                    damping: Double) {
        let combTunings = [1116, 1188, 1277, 1356]
        let allpassTunings = [556, 341]
        let spread = 23
        let feedback = 0.82

        for channel in 0..<2 {
            let offset = channel == 0 ? 0 : spread
            var wet = [Float](repeating: 0, count: send.count)

            for tuning in combTunings {
                let size = tuning + offset
                guard size < send.count else { continue }
                var filterStore: Float = 0
                var line = [Float](repeating: 0, count: send.count)
                for i in 0..<send.count {
                    let delayed = i >= size ? line[i - size] : 0
                    // Tarak içi sönümleme: yüksek frekanslar daha hızlı ölür.
                    filterStore = delayed * Float(1 - damping) + filterStore * Float(damping)
                    line[i] = send[i] + filterStore * Float(feedback)
                    wet[i] += delayed
                }
            }
            for tuning in allpassTunings {
                let size = tuning + offset
                guard size < wet.count else { continue }
                var line = [Float](repeating: 0, count: wet.count)
                for i in 0..<wet.count {
                    let delayed = i >= size ? line[i - size] : 0
                    line[i] = wet[i] + delayed * 0.5
                    wet[i] = delayed - wet[i] * 0.5
                }
            }
            for i in 0..<wet.count {
                if channel == 0 { buffer.left[i] += wet[i] * 0.28 }
                else { buffer.right[i] += wet[i] * 0.28 }
            }
        }
    }

    // MARK: - Master

    /// Yüksek geçiren + kompresör + limiter + normalizasyon + fade.
    /// Dinamikleri toparlar; parçanın "kaydedilmiş" gibi duyulmasını sağlar.
    private static func master(_ buffer: inout StereoBuffer) {
        let count = buffer.count
        var highpassL = 0.0, highpassR = 0.0
        let hpCoefficient = 1 - exp(-2 * Double.pi * 32 / sampleRate)
        var envelope = 0.0
        let attack = 1 - exp(-1 / (0.008 * sampleRate))
        let release = 1 - exp(-1 / (0.18 * sampleRate))
        let threshold = 0.30, ratio = 3.0

        // Tiz shelf: 3 kHz üstünü hafif kaldırır (parlaklık/hava). Filtreli
        // sentez tek başına fazla "kapalı" duyuluyor.
        var shelfL = 0.0, shelfR = 0.0
        let shelfCoefficient = 1 - exp(-2 * Double.pi * 3000 / sampleRate)
        let shelfGain = 0.9

        for i in 0..<count {
            // 32 Hz altını at (ped + kick birikmesi çamur yapıyor).
            highpassL += (Double(buffer.left[i]) - highpassL) * hpCoefficient
            highpassR += (Double(buffer.right[i]) - highpassR) * hpCoefficient
            var left = Double(buffer.left[i]) - highpassL
            var right = Double(buffer.right[i]) - highpassR

            shelfL += (left - shelfL) * shelfCoefficient
            shelfR += (right - shelfR) * shelfCoefficient
            left += (left - shelfL) * shelfGain
            right += (right - shelfR) * shelfGain

            // Kompresör (kanallar birlikte — stereo görüntü kaymasın).
            let peak = max(abs(left), abs(right))
            envelope += (peak - envelope) * (peak > envelope ? attack : release)
            var gain = 1.0
            if envelope > threshold {
                let over = envelope / threshold
                gain = pow(over, 1 / ratio - 1)
            }
            left *= gain * 1.5
            right *= gain * 1.5

            // Yumuşak limiter.
            buffer.left[i] = Float(tanh(left * 0.9))
            buffer.right[i] = Float(tanh(right * 0.9))
        }

        var peak: Float = 0
        for i in 0..<count { peak = max(peak, max(abs(buffer.left[i]), abs(buffer.right[i]))) }
        let normalize = peak > 0.0001 ? 0.85 / peak : 1

        let fadeIn = min(Int(0.03 * sampleRate), count)
        let fadeOut = min(Int(0.4 * sampleRate), count)
        for i in 0..<count {
            var gain = Double(normalize)
            if i < fadeIn { gain *= Double(i) / Double(fadeIn) }
            let fromEnd = count - i
            if fromEnd < fadeOut { gain *= Double(fromEnd) / Double(fadeOut) }
            buffer.left[i] *= Float(gain)
            buffer.right[i] *= Float(gain)
        }
    }

    // MARK: - Yardımcılar

    /// Chamberlin state-variable alçak geçiren filtre.
    private struct SVF {
        var low = 0.0, band = 0.0

        mutating func process(_ input: Double, cutoff: Double, resonance: Double,
                              poles: Int) -> Double {
            // Kararlılık için kesim frekansı sr/4'ün altında tutulur.
            let f = 2 * sin(.pi * min(cutoff, sampleRate * 0.24) / sampleRate)
            let q = max(0.2, 2 - resonance)
            for _ in 0..<(poles / 2) {
                let high = input - low - q * band
                band += f * high
                low += f * band
            }
            return low
        }
    }

    /// Sinüs tablosu — nota başına on binlerce `sin()` çağrısı sentezi
    /// gereksiz yavaşlatıyor.
    private static let sineTable: [Double] = (0...4096).map {
        sin(2 * .pi * Double($0) / 4096)
    }

    /// Faz (devir cinsinden) -> sinüs. Tablo + doğrusal ara değer.
    @inline(__always)
    private static func sine(_ phase: Double) -> Double {
        let wrapped = phase - floor(phase)
        let position = wrapped * 4096
        let index = Int(position)
        let fraction = position - Double(index)
        return sineTable[index] + (sineTable[index + 1] - sineTable[index]) * fraction
    }

    struct Hit {
        var step: Int
        /// Adım cinsinden uzunluk (`-` ile uzatılır).
        var length: Int
        var char: Character
    }

    /// 16 adımlık deseni vuruşlara çevirir. `.` sus, `-` önceki vuruşu uzatır.
    static func parse(_ pattern: String) -> [Hit] {
        var hits: [Hit] = []
        for (index, char) in pattern.enumerated() {
            switch char {
            case ".", " ":
                continue
            case "-":
                if !hits.isEmpty { hits[hits.count - 1].length += 1 }
            default:
                hits.append(Hit(step: index, length: 1, char: char))
            }
        }
        return hits
    }

    /// Deterministik gürültü kaynağı (sistem RNG'si kullanılsa aynı parça her
    /// üretimde farklı çıkardı; testler ve cache bunu istemez).
    struct LCG {
        private var state: UInt64
        init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        /// -1...1 arası düzgün dağılımlı gürültü.
        mutating func nextBipolar() -> Double {
            Double(next() >> 11) / Double(1 << 53) * 2 - 1
        }
    }
}
