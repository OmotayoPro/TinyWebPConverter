import ImageIO
import UniformTypeIdentifiers
import Foundation

public enum FileValidator {
    /// Identifies the file's format by sniffing its contents via ImageIO (not by file extension),
    /// and rejects anything outside the curated list (PRD §6.1).
    public static func validate(url: URL) -> Result<SupportedImageFormat, ConversionError> {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let utTypeIdentifier = CGImageSourceGetType(source) as String? else {
            return .failure(.unsupportedFormat(reason: "This file format isn't supported"))
        }

        if let format = SupportedImageFormat.matching(utTypeIdentifier: utTypeIdentifier) {
            return .success(format)
        }

        if let utType = UTType(utTypeIdentifier), utType.conforms(to: .rawImage) {
            return .failure(.unsupportedFormat(reason: "Camera RAW files aren't supported yet"))
        }

        return .failure(.unsupportedFormat(reason: "This file format isn't supported"))
    }
}
