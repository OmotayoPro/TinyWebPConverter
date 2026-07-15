import CoreGraphics

enum ImageTransformer {
    static func resized(_ image: CGImage, to targetSize: CGSize) throws -> CGImage {
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        guard width != image.width || height != image.height else { return image }

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.encodeFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let resized = context.makeImage() else {
            throw ConversionError.encodeFailed
        }
        return resized
    }
}
