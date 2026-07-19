import Foundation

public enum ConversionError: Error, LocalizedError, Equatable, Sendable {
    /// A file that isn't one of the curated input formats (PRD §6.1). `reason` is the
    /// user-facing subtext — e.g. "Camera RAW files aren't supported yet" for RAW specifically,
    /// or a generic "This file format isn't supported" otherwise.
    case unsupportedFormat(reason: String)
    case decodeFailed
    case corruptedImage
    case encodeFailed
    case writeFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let reason):
            return reason
        case .decodeFailed, .corruptedImage:
            return "This file appears to be corrupted or unreadable."
        case .encodeFailed:
            return "Image encoding failed."
        case .writeFailed(let underlying):
            return "Couldn't write the output file: \(underlying)"
        }
    }
}
