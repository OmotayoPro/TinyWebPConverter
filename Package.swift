// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TinyWebPCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TinyWebPCore", targets: ["TinyWebPCore"])
    ],
    dependencies: [
        // ImageIO can decode WebP but cannot encode it on any current macOS version
        // (verified empirically: WebP is absent from CGImageDestinationCopyTypeIdentifiers()).
        // libwebp is linked solely for the encode step; everything else (decode, resize,
        // metadata handling) stays on ImageIO/CoreGraphics.
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "TinyWebPCore",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-Xcode")
            ]
        ),
        .testTarget(name: "TinyWebPCoreTests", dependencies: ["TinyWebPCore"])
    ]
)
