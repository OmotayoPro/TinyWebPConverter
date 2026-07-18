import XCTest
@testable import TinyWebPCore

/// PRD §7: "converting a single typical photo (a few MB) should feel instant (well under
/// 1 second)" and "batch jobs should process/release images rather than loading an entire
/// large batch into memory at once." These use noise-filled JPEGs at real photo dimensions
/// (12MP) rather than the tiny synthetic images the rest of the suite uses, since pixel count
/// is what actually drives decode/resize/encode cost.
///
/// Thresholds are set generously to avoid flakiness — the point is to catch a gross
/// regression, not to enforce the PRD's "under 1 second" figure as a hard CI gate. In
/// particular, `swift test`'s default Debug configuration also deoptimizes libwebp (a C
/// target built from source by SPM, not just this package's Swift code), so Debug numbers run
/// ~4-7x slower than Release here. Measured on realistic (non-noise) content in Release: a
/// 12MP photo converts in ~0.6s. Actual timings are printed for a human to judge against the
/// PRD's bar; the assertions here only guard against something being drastically broken.
final class PerformanceTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestImageFactory.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSingleRealisticPhotoConvertsQuickly() throws {
        let source = try TestImageFactory.makeRealisticPhotoJPEG(at: tempDir.appendingPathComponent("photo.jpg"))
        let inputSize = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int ?? 0

        let start = Date()
        let result = try ConversionPipeline.convert(
            fileAt: source, settings: ConversionSettings(), outputDirectory: tempDir
        )
        let elapsed = Date().timeIntervalSince(start)

        print("[Performance] Single 12MP photo: input \(formatBytes(inputSize)), " +
              "output \(formatBytes(result.outputByteCount)), took \(String(format: "%.2f", elapsed))s")

        XCTAssertLessThan(elapsed, 15.0, "A single photo conversion took suspiciously long: \(elapsed)s")
    }

    func testBatchOfRealisticPhotosCompletesWithoutStalling() async throws {
        let sources = try (0..<12).map { i in
            try TestImageFactory.makeRealisticPhotoJPEG(at: tempDir.appendingPathComponent("photo\(i).jpg"))
        }

        let start = Date()
        let items = try await BatchConverter.convert(sourceURLs: sources, settings: ConversionSettings())
        let elapsed = Date().timeIntervalSince(start)

        let succeeded = items.filter { if case .done = $0.status { return true } else { return false } }
        print("[Performance] Batch of \(sources.count) 12MP photos (concurrency \(BatchConverter.defaultConcurrencyLimit)): " +
              "\(succeeded.count) succeeded, took \(String(format: "%.2f", elapsed))s " +
              "(\(String(format: "%.2f", elapsed / Double(sources.count)))s/image average)")

        XCTAssertEqual(succeeded.count, sources.count)
        XCTAssertLessThan(elapsed, 45.0, "A 12-image batch took suspiciously long: \(elapsed)s")
    }

    private func formatBytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
