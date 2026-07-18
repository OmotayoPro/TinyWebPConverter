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
        let q = lossless ? 1.0 : Double(quality) / 100.0
        CGImageDestinationAddImage(destination, image,
            [kCGImageDestinationLossyCompressionQuality: q] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.encodeFailed
        }
        return mutableData as Data
    }
}
