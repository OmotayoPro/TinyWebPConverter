import XCTest
@testable import TinyWebPCore

final class BatchConverterTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestImageFactory.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDefaultOutputDirectoryMatchesEachSourceFolder() async throws {
        let subDirA = tempDir.appendingPathComponent("a", isDirectory: true)
        let subDirB = tempDir.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: subDirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subDirB, withIntermediateDirectories: true)

        let sourceA = try TestImageFactory.makePNG(at: subDirA.appendingPathComponent("photo.png"))
        let sourceB = try TestImageFactory.makePNG(at: subDirB.appendingPathComponent("photo.png"))

        let items = try await BatchConverter.convert(sourceURLs: [sourceA, sourceB], settings: ConversionSettings())

        for item in items {
            guard case .done(let result) = item.status else {
                return XCTFail("Expected .done for \(item.sourceURL), got \(item.status)")
            }
            XCTAssertEqual(result.outputURL.deletingLastPathComponent(), item.sourceURL.deletingLastPathComponent())
        }
    }

    func testEmptyBatchReturnsEmpty() async throws {
        let items = try await BatchConverter.convert(sourceURLs: [], settings: ConversionSettings(), outputDirectory: tempDir)
        XCTAssertTrue(items.isEmpty)
    }

    func testThrowsWhenOverBatchLimit() async {
        let tooMany = (0..<(BatchConverter.maxBatchSize + 1)).map { tempDir.appendingPathComponent("img\($0).png") }

        do {
            _ = try await BatchConverter.convert(sourceURLs: tooMany, settings: ConversionSettings(), outputDirectory: tempDir)
            XCTFail("Expected batchTooLarge to be thrown")
        } catch let error as BatchConversionError {
            guard case .batchTooLarge(let count, let limit) = error else {
                return XCTFail("Expected .batchTooLarge, got \(error)")
            }
            XCTAssertEqual(count, BatchConverter.maxBatchSize + 1)
            XCTAssertEqual(limit, BatchConverter.maxBatchSize)
        } catch {
            XCTFail("Expected BatchConversionError, got \(error)")
        }
    }

    func testConvertsAllImagesInBatch() async throws {
        let sources = try (0..<6).map { i in
            try TestImageFactory.makePNG(width: 10, height: 10, at: tempDir.appendingPathComponent("img\(i).png"))
        }

        let items = try await BatchConverter.convert(
            sourceURLs: sources, settings: ConversionSettings(), outputDirectory: tempDir, concurrencyLimit: 2
        )

        XCTAssertEqual(items.count, 6)
        for item in items {
            guard case .done(let result) = item.status else {
                return XCTFail("Expected .done for \(item.sourceURL), got \(item.status)")
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL.path))
        }
    }

    func testOneFailureDoesNotStopTheRestOfTheBatch() async throws {
        let good1 = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("good1.png"))
        let good2 = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("good2.png"))
        let bad = tempDir.appendingPathComponent("bad.txt")
        try "not an image".write(to: bad, atomically: true, encoding: .utf8)
        let good3 = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("good3.png"))

        let items = try await BatchConverter.convert(
            sourceURLs: [good1, bad, good2, good3], settings: ConversionSettings(), outputDirectory: tempDir, concurrencyLimit: 2
        )

        XCTAssertEqual(items.count, 4)

        let badItem = try XCTUnwrap(items.first { $0.sourceURL == bad })
        guard case .failed(let error) = badItem.status else {
            return XCTFail("Expected the unsupported file to fail, got \(badItem.status)")
        }
        guard case .unsupportedFormat = error else {
            return XCTFail("Expected .unsupportedFormat, got \(error)")
        }

        let succeeded = items.filter { $0.sourceURL != bad }
        for item in succeeded {
            guard case .done = item.status else {
                return XCTFail("Expected \(item.sourceURL) to succeed, got \(item.status)")
            }
        }
    }

    func testStatusChangesFromConvertingToTerminalForEveryItem() async throws {
        let sources = try (0..<4).map { i in
            try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("img\(i).png"))
        }

        let recorder = StatusRecorder()
        _ = try await BatchConverter.convert(
            sourceURLs: sources, settings: ConversionSettings(), outputDirectory: tempDir, concurrencyLimit: 2
        ) { url, status in
            recorder.record(url: url, status: status)
        }

        let byItem = recorder.eventsByItem()
        XCTAssertEqual(byItem.count, 4)
        for (_, statuses) in byItem {
            XCTAssertEqual(statuses.first, .converting)
            guard case .done = statuses.last! else {
                return XCTFail("Expected final status to be .done, got \(statuses.last!)")
            }
        }
    }
}

/// Serializes concurrent status-callback writes for the test above.
private final class StatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [(URL, BatchItemStatus)] = []

    func record(url: URL, status: BatchItemStatus) {
        lock.lock()
        defer { lock.unlock() }
        events.append((url, status))
    }

    func eventsByItem() -> [URL: [BatchItemStatus]] {
        lock.lock()
        defer { lock.unlock() }
        return Dictionary(grouping: events, by: { $0.0 }).mapValues { $0.map(\.1) }
    }
}
