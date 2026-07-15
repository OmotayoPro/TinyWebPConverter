import libwebp
import Foundation

/// Wraps a bare WebP bitstream in an extended-format container carrying an EXIF chunk, via
/// libwebp's mux API.
enum WebPMetadataWriter {
    static func attachingExif(_ exif: Data, to webpBitstream: Data) throws -> Data {
        guard let mux = WebPMuxNew() else {
            throw ConversionError.encodeFailed
        }
        defer { WebPMuxDelete(mux) }

        let imageSetResult: WebPMuxError = webpBitstream.withUnsafeBytes { rawBuffer in
            var imageData = WebPData(bytes: rawBuffer.bindMemory(to: UInt8.self).baseAddress, size: rawBuffer.count)
            return WebPMuxSetImage(mux, &imageData, 1)
        }
        guard imageSetResult == WEBP_MUX_OK else {
            throw ConversionError.encodeFailed
        }

        let chunkSetResult: WebPMuxError = exif.withUnsafeBytes { rawBuffer in
            var exifData = WebPData(bytes: rawBuffer.bindMemory(to: UInt8.self).baseAddress, size: rawBuffer.count)
            return "EXIF".withCString { fourcc in
                WebPMuxSetChunk(mux, fourcc, &exifData, 1)
            }
        }
        guard chunkSetResult == WEBP_MUX_OK else {
            throw ConversionError.encodeFailed
        }

        var assembled = WebPData(bytes: nil, size: 0)
        defer { WebPDataClear(&assembled) }

        guard WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK, let bytes = assembled.bytes else {
            throw ConversionError.encodeFailed
        }

        return Data(bytes: bytes, count: assembled.size)
    }
}
