import XCTest
import ImageIO
@testable import TinyWebPCore

final class ConversionPipelineTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestImageFactory.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testConvertProducesADecodableWebPFileAtOriginalDimensions() throws {
        let source = try TestImageFactory.makePNG(width: 12, height: 8, at: tempDir.appendingPathComponent("input.png"))

        let result = try ConversionPipeline.convert(
            fileAt: source,
            settings: ConversionSettings(),
            outputDirectory: tempDir
        )

        XCTAssertEqual(result.outputURL.pathExtension, "webp")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        XCTAssertGreaterThan(result.outputByteCount, 0)

        let decoded = try XCTUnwrap(decodedImage(at: result.outputURL))
        XCTAssertEqual(decoded.width, 12)
        XCTAssertEqual(decoded.height, 8)
    }

    func testConvertAutoRenamesOnRepeatedConversion() throws {
        let source = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("input.png"))
        let settings = ConversionSettings()

        let first = try ConversionPipeline.convert(fileAt: source, settings: settings, outputDirectory: tempDir)
        let second = try ConversionPipeline.convert(fileAt: source, settings: settings, outputDirectory: tempDir)

        XCTAssertEqual(first.outputURL.lastPathComponent, "input.webp")
        XCTAssertEqual(second.outputURL.lastPathComponent, "input (1).webp")
        XCTAssertNotEqual(first.outputURL, second.outputURL)
    }

    func testConvertAppliesResize() throws {
        let source = try TestImageFactory.makePNG(width: 40, height: 20, at: tempDir.appendingPathComponent("input.png"))
        let settings = ConversionSettings(resize: .percentage(50))

        let result = try ConversionPipeline.convert(fileAt: source, settings: settings, outputDirectory: tempDir)
        let decoded = try XCTUnwrap(decodedImage(at: result.outputURL))

        XCTAssertEqual(decoded.width, 20)
        XCTAssertEqual(decoded.height, 10)
    }

    func testLosslessProducesLargerOutputThanLowQualityLossy() throws {
        let source = try TestImageFactory.makeNoisyPNG(width: 64, height: 64, at: tempDir.appendingPathComponent("input.png"))

        let lossy = try ConversionPipeline.convert(
            fileAt: source, settings: ConversionSettings(quality: 5, lossless: false), outputDirectory: tempDir
        )
        let lossless = try ConversionPipeline.convert(
            fileAt: source, settings: ConversionSettings(quality: 5, lossless: true), outputDirectory: tempDir
        )

        XCTAssertGreaterThan(lossless.outputByteCount, lossy.outputByteCount)
    }

    func testEncodePreviewWritesNothingToDisk() throws {
        let source = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("input.png"))
        let before = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)

        let data = try ConversionPipeline.encodePreview(fileAt: source, settings: ConversionSettings())

        let after = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(before.sorted(), after.sorted())
    }

    func testRejectsUnsupportedFile() throws {
        let url = tempDir.appendingPathComponent("notes.txt")
        try "not an image".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConversionPipeline.convert(fileAt: url, settings: ConversionSettings(), outputDirectory: tempDir)) { error in
            guard case ConversionError.unsupportedFormat = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
        }
    }

    func testKeepMetadataCarriesExifAndGPSIntoOutput() throws {
        let source = try TestImageFactory.makeJPEGWithMetadata(at: tempDir.appendingPathComponent("input.jpg"))
        let settings = ConversionSettings(keepMetadata: true)

        let result = try ConversionPipeline.convert(fileAt: source, settings: settings, outputDirectory: tempDir)
        let properties = try XCTUnwrap(decodedProperties(at: result.outputURL))

        XCTAssertNotNil(properties[kCGImagePropertyExifDictionary])
        XCTAssertNotNil(properties[kCGImagePropertyGPSDictionary])
    }

    func testStripMetadataOmitsExifAndGPSFromOutput() throws {
        let source = try TestImageFactory.makeJPEGWithMetadata(at: tempDir.appendingPathComponent("input.jpg"))
        let settings = ConversionSettings(keepMetadata: false)

        let result = try ConversionPipeline.convert(fileAt: source, settings: settings, outputDirectory: tempDir)
        let properties = decodedProperties(at: result.outputURL) ?? [:]

        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
    }

    // MARK: - Helpers

    private func decodedImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func decodedProperties(at url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }
}
