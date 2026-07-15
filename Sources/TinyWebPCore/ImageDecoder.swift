import ImageIO
import CoreGraphics
import Foundation

enum ImageDecoder {
    static func decode(url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ConversionError.decodeFailed
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ConversionError.corruptedImage
        }
        return image
    }

    /// Raw EXIF/GPS/TIFF properties as ImageIO reports them, used to decide whether there's
    /// anything to carry forward when `keepMetadata` is on.
    static func properties(url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return properties
    }
}
