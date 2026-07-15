import CoreGraphics

struct RGBAPixelBuffer {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    /// libwebp's `WebPPictureImportRGBA` expects straight (non-premultiplied) alpha, but
    /// CGBitmapContext only ever draws premultiplied alpha into an 8bpc RGBA buffer — so we
    /// draw premultiplied, then unpremultiply each pixel by hand before handing bytes to libwebp.
    static func straightAlpha(from image: CGImage) throws -> RGBAPixelBuffer {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        try buffer.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ConversionError.encodeFailed
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        buffer.withUnsafeMutableBufferPointer { pixels in
            let pixelCount = width * height
            for i in 0..<pixelCount {
                let base = i * 4
                let alpha = pixels[base + 3]
                guard alpha != 0, alpha != 255 else { continue }
                let a = Double(alpha)
                for channel in 0..<3 {
                    let straight = (Double(pixels[base + channel]) * 255.0 / a).rounded()
                    pixels[base + channel] = UInt8(min(255.0, max(0.0, straight)))
                }
            }
        }

        return RGBAPixelBuffer(bytes: buffer, width: width, height: height)
    }
}
