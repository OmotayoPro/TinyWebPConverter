import ImageIO
import UniformTypeIdentifiers
import Foundation

/// libwebp's EXIF chunk payload must be a raw TIFF-structured EXIF blob (the same bytes a JPEG's
/// APP1 segment carries, minus the 6-byte "Exif\0\0" prefix) — see the WebP container spec.
/// ImageIO has no direct "give me the raw EXIF blob" API, so we get one indirectly: write the
/// source's metadata properties into a throwaway in-memory JPEG (ImageIO serializes them into a
/// real APP1/EXIF segment for us), then pull that segment back out.
enum ExifBlobExtractor {
    static func extract(properties: [CFString: Any]) -> Data? {
        guard !properties.isEmpty else { return nil }

        let pixel = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        defer { pixel.deallocate() }
        pixel[0] = 0; pixel[1] = 0; pixel[2] = 0; pixel[3] = 255
        guard let context = CGContext(
            data: pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let placeholderImage = context.makeImage() else {
            return nil
        }

        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, placeholderImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return extractExifSegment(fromJPEG: jpegData as Data)
    }

    /// Scans JPEG markers for APP1 (0xFFE1) whose payload starts with "Exif\0\0", and returns
    /// everything after that 6-byte prefix.
    private static func extractExifSegment(fromJPEG data: Data) -> Data? {
        let bytes = [UInt8](data)
        var offset = 2 // skip SOI (0xFFD8)
        let exifPrefix: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00] // "Exif\0\0"

        while offset + 4 <= bytes.count, bytes[offset] == 0xFF {
            let marker = bytes[offset + 1]
            if marker == 0xD8 || marker == 0x01 || (0xD0...0xD7).contains(marker) {
                offset += 2
                continue
            }
            if marker == 0xD9 { break } // EOI
            let length = Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            let payloadStart = offset + 4
            let payloadEnd = offset + 2 + length
            guard payloadEnd <= bytes.count, payloadStart <= payloadEnd else { return nil }

            if marker == 0xE1, payloadEnd - payloadStart > exifPrefix.count,
               Array(bytes[payloadStart..<payloadStart + exifPrefix.count]) == exifPrefix {
                return Data(bytes[(payloadStart + exifPrefix.count)..<payloadEnd])
            }
            offset = payloadEnd
        }
        return nil
    }
}
