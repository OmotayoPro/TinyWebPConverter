import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

enum TestImageFactory {
    enum FactoryError: Error { case setupFailed }

    @discardableResult
    static func makePNG(width: Int = 8, height: Int = 8, at url: URL) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FactoryError.setupFailed }

        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Double(width) / 2, height: Double(height)))
        context.setFillColor(CGColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 0.4))
        context.fill(CGRect(x: Double(width) / 2, y: 0, width: Double(width) / 2, height: Double(height)))

        guard let cgImage = context.makeImage() else { throw FactoryError.setupFailed }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw FactoryError.setupFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw FactoryError.setupFailed }
        return url
    }

    /// A JPEG carrying real EXIF (UserComment) and GPS (Latitude) metadata, for round-trip tests.
    @discardableResult
    static func makeJPEGWithMetadata(width: Int = 8, height: Int = 8, at url: URL) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw FactoryError.setupFailed }

        context.setFillColor(CGColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Double(width), height: Double(height)))

        guard let cgImage = context.makeImage() else { throw FactoryError.setupFailed }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FactoryError.setupFailed
        }

        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifUserComment: "tiny-webp-converter-test"
            ],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.7749,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.4194,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
        ]

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FactoryError.setupFailed }
        return url
    }

    /// Random per-pixel noise — unlike a flat/gradient image, noise can't be cheaply predicted,
    /// so lossless is reliably larger than aggressively-quantized lossy output.
    @discardableResult
    static func makeNoisyPNG(width: Int = 64, height: Int = 64, at url: URL) throws -> URL {
        var generator = SystemRandomNumberGenerator()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let base = i * 4
            pixels[base] = UInt8.random(in: 0...255, using: &generator)
            pixels[base + 1] = UInt8.random(in: 0...255, using: &generator)
            pixels[base + 2] = UInt8.random(in: 0...255, using: &generator)
            pixels[base + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = pixels.withUnsafeMutableBytes({ rawBuffer -> CGContext? in
            CGContext(
                data: rawBuffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        }), let cgImage = context.makeImage() else { throw FactoryError.setupFailed }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw FactoryError.setupFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw FactoryError.setupFailed }
        return url
    }

    /// A JPEG at real photo dimensions (default: 12MP, a typical phone photo). Filled with
    /// noise via `arc4random_buf` rather than a per-pixel loop so generation itself stays fast
    /// at this pixel count — this is deliberately high-entropy, worst-case-ish content for a
    /// timing test (real photos compress better than noise), so a pass here is a conservative
    /// bound on real-world speed, not an optimistic one.
    @discardableResult
    static func makeRealisticPhotoJPEG(width: Int = 4032, height: Int = 3024, at url: URL) throws -> URL {
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        buffer.withUnsafeMutableBytes { raw in
            arc4random_buf(raw.baseAddress, raw.count)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = buffer.withUnsafeMutableBytes({ rawBuffer -> CGContext? in
            CGContext(
                data: rawBuffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        }), let cgImage = context.makeImage() else { throw FactoryError.setupFailed }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FactoryError.setupFailed
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { throw FactoryError.setupFailed }
        return url
    }

    static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
