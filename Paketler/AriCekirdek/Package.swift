// swift-tools-version: 5.10
// BeeBook çekirdeği: yalnız Foundation kullanan model, eşitleme ve hesap mantığı.
// Linux CI'da `swift test` ile sınanır; iOS uygulaması bu paketi kullanır.
import PackageDescription

let package = Package(
    name: "AriCekirdek",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AriCekirdek", targets: ["AriCekirdek"])
    ],
    targets: [
        .target(name: "AriCekirdek"),
        .testTarget(
            name: "AriCekirdekTests",
            dependencies: ["AriCekirdek"],
            resources: [.copy("Ornekler")]
        )
    ]
)
