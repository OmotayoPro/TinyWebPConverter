import ImageIO
import CoreGraphics
import Foundation

enum AVIFEncoder {
    static func encode(image: CGImage, quality: Int, lossless: Bool) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData, "public.avif" as CFString, 1, nil
        ) else {
            throw ConversionError.encodeFailed
        }
        // ImageIO's AVIF encoder fails to finalize at exactly 1.0 (it has no
        // lossless AV1 support), so cap at 0.99 — the UI hides the lossless
        // option for AVIF, but this keeps direct API callers from failing.
        let q = min(lossless ? 1.0 : Double(quality) / 100.0, 0.99)
        CGImageDestinationAddImage(destination, image,
            [kCGImageDestinationLossyCompressionQuality: q] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.encodeFailed
        }
        return mutableData as Data
    }
}
