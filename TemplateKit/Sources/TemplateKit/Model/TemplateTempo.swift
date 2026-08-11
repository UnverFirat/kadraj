import Foundation

/// Şablonu seçilen parçanın TEMPOSUNA oturtur.
///
/// SORUN: şablon süreleri saniye cinsinden yazılıyor, müzik ise kullanıcı
/// tarafından çalışma anında seçiliyor. 6,0 saniyelik bir şablon 116 BPM'lik
/// bir parçayla eşleştiğinde video ölçünün ortasında bitiyor — müzik yarım
/// kalmış gibi kesiliyor ve kesmelerin ritimle hiçbir ilişkisi olmuyor. Bu,
/// katalogun "slayt gibi" hissedilmesinin ölçülebilir sebeplerinden biriydi
/// (`bpm` render katmanına HİÇ ulaşmıyordu).
///
/// ÇÖZÜM: videonun toplam süresini en yakın TAM ÖLÇÜYE (bar) yuvarlayıp tüm
/// zamanları aynı oranda ölçekliyoruz. Bunun bizde işe yaramasının sebebi
/// müziğin dosya değil TARİF olması — `MusicLibrary.materialize` parçayı
/// istenen uzunlukta üretiyor, yani süre tam ölçüye oturunca parça da tam
/// ölçüde bitiyor. Ek olarak katman girişleri ölçü içinde hep aynı orana
/// düştüğü için vuruşlarla tutarlı hale geliyor.
///
/// Neden sahne sınırlarını tek tek vuruşa "snap" ETMİYORUZ: şablon yazarının
/// kurduğu kademeli girişler (0,1 sn arayla giren kelimeler) vuruş ızgarasına
/// çekilince üst üste biner ve tasarım bozulur. Oranı korumak hem müzikal
/// hem de tasarıma saygılı.
public enum TemplateTempo {

    /// Bir ölçü (4/4 varsayımı — kütüphanedeki parçaların tamamı 4/4).
    public static func barLength(bpm: Int) -> Double {
        guard bpm > 0 else { return 0 }
        return 4 * 60 / Double(bpm)
    }

    /// Şablonu tempoya hizalanmış bir kopyayla döndürür.
    ///
    /// - Parameter maxStretch: sürenin en fazla ne kadar değişebileceği
    ///   (0.15 = ±%15). Şablon yazarının süresi bir tasarım kararı; ölçüye
    ///   oturtmak için videoyu iki katına çıkarmak kabul edilemez. Gerekli
    ///   esneme bu sınırı aşıyorsa şablon OLDUĞU GİBİ bırakılır.
    public static func aligned(_ template: Template, bpm: Int,
                               maxStretch: Double = 0.15) -> Template {
        let bar = barLength(bpm: bpm)
        let current = template.totalDuration
        guard bar > 0, current > 0 else { return template }

        // En yakın tam ölçü (en az bir ölçü).
        let bars = max(1, (current / bar).rounded())
        let target = bars * bar
        let scale = target / current
        guard abs(scale - 1) <= maxStretch else { return template }
        // Kayda değer bir fark yoksa dokunma (gereksiz yeniden render olmasın).
        guard abs(target - current) > 0.02 else { return template }

        return template.timeScaled(by: scale)
    }
}

extension Template {
    /// Tüm zaman değerlerini aynı oranda ölçekler: süre, sahne süreleri,
    /// geçişler, katman pencereleri ve animasyonlar. Oran korunduğu için
    /// tasarımın ritmi (neyin ne zaman girdiği) aynı kalır.
    public func timeScaled(by scale: Double) -> Template {
        guard scale > 0, scale != 1 else { return self }
        var copy = self
        copy.explicitDuration = explicitDuration.map { $0 * scale }
        copy.layers = layers.map { $0.timeScaled(by: scale) }
        copy.scenes = scenes?.map { scene in
            var s = scene
            s.duration *= scale
            s.layers = scene.layers.map { $0.timeScaled(by: scale) }
            if let transition = scene.transition {
                s.transition = TransitionSpec(style: transition.style,
                                             duration: transition.duration * scale)
            }
            return s
        }
        return copy
    }
}

extension Layer {
    func timeScaled(by scale: Double) -> Layer {
        var copy = self
        copy.timing = Timing(start: timing.start * scale,
                             duration: timing.duration.map { $0 * scale })
        copy.animations = animations.map { animation in
            var a = animation
            a.delay *= scale
            a.duration *= scale
            return a
        }
        return copy
    }
}
