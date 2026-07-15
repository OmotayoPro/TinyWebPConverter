import UniformTypeIdentifiers

/// The curated set of input formats accepted in v1 (PRD §6.1). Anything else — including
/// Camera RAW, which ImageIO can decode but which is deliberately out of scope for v1 — is rejected.
public enum SupportedImageFormat: String, CaseIterable, Sendable {
    case png
    case jpeg
    case heic
    case tiff
    case gif
    case bmp

    var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .tiff: return .tiff
        case .gif: return .gif
        case .bmp: return .bmp
        }
    }

    static func matching(utTypeIdentifier: String) -> SupportedImageFormat? {
        guard let utType = UTType(utTypeIdentifier) else { return nil }
        return allCases.first { utType.conforms(to: $0.utType) }
    }
}
