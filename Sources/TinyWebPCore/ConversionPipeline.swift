import Foundation
import CoreGraphics

public struct ConversionResult: Sendable, Equatable {
    public let sourceURL: URL
    public let outputURL: URL
    public let originalByteCount: Int
    public let outputByteCount: Int
}

/// The six-step pipeline from the session notes: validate -> decode -> transform (resize, strip
/// metadata) -> encode as WebP or AVIF -> write to disk -> report. `encodePreview` reuses the same
/// encode step but targets memory instead of disk, for the live before/after preview.
public enum ConversionPipeline {
    public static func convert(
        fileAt sourceURL: URL,
        settings: ConversionSettings,
        outputDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> ConversionResult {
        let encoded = try encodedData(fileAt: sourceURL, settings: settings)

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = OutputPathResolver.resolve(
            baseName: baseName,
            extension: settings.outputFormat.fileExtension,
            directory: outputDirectory,
            fileManager: fileManager
        )

        do {
            try encoded.write(to: outputURL, options: .atomic)
        } catch {
            throw ConversionError.writeFailed(underlying: error.localizedDescription)
        }

        let originalByteCount = (try? fileManager.attributesOfItem(atPath: sourceURL.path))?[.size] as? Int ?? 0

        return ConversionResult(
            sourceURL: sourceURL,
            outputURL: outputURL,
            originalByteCount: originalByteCount,
            outputByteCount: encoded.count
        )
    }

    /// In-memory-only encode for the live preview (PRD §6.3) — nothing touches disk.
    public static func encodePreview(fileAt sourceURL: URL, settings: ConversionSettings) throws -> Data {
        try encodedData(fileAt: sourceURL, settings: settings)
    }

    private static func encodedData(fileAt sourceURL: URL, settings: ConversionSettings) throws -> Data {
        switch FileValidator.validate(url: sourceURL) {
        case .failure(let error): throw error
        case .success: break
        }

        let decoded = try ImageDecoder.decode(url: sourceURL)
        let targetSize = settings.resize.targetSize(for: CGSize(width: decoded.width, height: decoded.height))
        let transformed = try ImageTransformer.resized(decoded, to: targetSize)

        switch settings.outputFormat {
        case .avif:
            return try AVIFEncoder.encode(image: transformed, quality: settings.quality, lossless: settings.lossless)
        case .webp:
            let bitstream = try WebPEncoder.encode(image: transformed, quality: settings.quality, lossless: settings.lossless)
            guard settings.keepMetadata,
                  let properties = ImageDecoder.properties(url: sourceURL),
                  let exif = ExifBlobExtractor.extract(properties: properties) else {
                return bitstream
            }
            // Best-effort: if muxing metadata back in fails for any reason, ship the (already valid)
            // metadata-stripped bitstream rather than failing the whole conversion.
            return (try? WebPMetadataWriter.attachingExif(exif, to: bitstream)) ?? bitstream
        }
    }
}
