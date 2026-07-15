import libwebp
import CoreGraphics
import Foundation

enum WebPEncoder {
    /// Produces a bare WebP bitstream (no EXIF/mux chunks — see WebPMetadataWriter for that).
    static func encode(image: CGImage, quality: Int, lossless: Bool) throws -> Data {
        let pixels = try RGBAPixelBuffer.straightAlpha(from: image)
        let clampedQuality = Float(min(max(quality, 0), 100))

        var config = WebPConfig()
        guard WebPConfigPreset(&config, WEBP_PRESET_DEFAULT, clampedQuality) != 0 else {
            throw ConversionError.encodeFailed
        }
        config.lossless = lossless ? 1 : 0
        config.quality = lossless ? 100 : clampedQuality
        config.method = 6

        guard WebPValidateConfig(&config) != 0 else {
            throw ConversionError.encodeFailed
        }

        var picture = WebPPicture()
        guard WebPPictureInit(&picture) != 0 else {
            throw ConversionError.encodeFailed
        }
        picture.width = Int32(pixels.width)
        picture.height = Int32(pixels.height)
        picture.use_argb = 1

        let imported: Int32 = pixels.bytes.withUnsafeBufferPointer { buffer in
            WebPPictureImportRGBA(&picture, buffer.baseAddress, Int32(pixels.width * 4))
        }
        guard imported != 0 else {
            WebPPictureFree(&picture)
            throw ConversionError.encodeFailed
        }

        var writer = WebPMemoryWriter()
        WebPMemoryWriterInit(&writer)
        picture.writer = WebPMemoryWrite

        let encodeResult: Int32 = withUnsafeMutablePointer(to: &writer) { writerPointer -> Int32 in
            picture.custom_ptr = UnsafeMutableRawPointer(writerPointer)
            return WebPEncode(&config, &picture)
        }

        defer {
            WebPPictureFree(&picture)
            WebPMemoryWriterClear(&writer)
        }

        guard encodeResult != 0, let mem = writer.mem else {
            throw ConversionError.encodeFailed
        }

        return Data(bytes: mem, count: writer.size)
    }
}
