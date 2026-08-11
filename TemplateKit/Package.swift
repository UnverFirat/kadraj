// swift-tools-version: 5.9
import PackageDescription

// TemplateKit: şablon modeli + render motoru çekirdeği.
// ÇEKİRDEK BAĞIMLILIKSIZ: `TemplateKit` hedefi hiçbir üçüncü parti kütüphaneye
// bağlı değil. Lottie desteği ayrı bir hedefte (`TemplateKitLottie`) duruyor;
// isteyen bağlar, motor onsuz da tam çalışır (lottie katmanı yer tutucu olur).
// macOS hedefi yalnızca testlerin Mac'te koşabilmesi için var; ürün hedefi iOS.
let package = Package(
    name: "TemplateKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TemplateKit", targets: ["TemplateKit"]),
        // Lottie adaptörü — uygulama ve CLI'lar bunu bağlar.
        .library(name: "TemplateKitLottie", targets: ["TemplateKitLottie"]),
        // Export hattını Mac'te uçtan uca doğrulayan CLI (uygulamaya gömülmez).
        .executable(name: "templatekit-demo", targets: ["TemplateKitDemo"]),
        // Galeri varlıklarını (thumbs/ + previews/) üreten CLI.
        .executable(name: "templatekit-assets", targets: ["TemplateKitAssets"])
    ],
    dependencies: [
        // YALNIZ `TemplateKitLottie` hedefi kullanır; çekirdek hedef görmez.
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.5.2")
    ],
    targets: [
        .target(name: "TemplateKit"),
        .target(name: "TemplateKitLottie",
                dependencies: ["TemplateKit", .product(name: "Lottie", package: "lottie-ios")]),
        .executableTarget(name: "TemplateKitDemo",
                          dependencies: ["TemplateKit", "TemplateKitLottie"]),
        .executableTarget(name: "TemplateKitAssets",
                          dependencies: ["TemplateKit", "TemplateKitLottie"]),
        .testTarget(
            name: "TemplateKitTests",
            dependencies: ["TemplateKit", "TemplateKitLottie"],
            resources: [.copy("Fixtures")]
        )
    ]
)
