import XCTest
@testable import TinyWebPCore

final class FileValidatorTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestImageFactory.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testAcceptsPNG() throws {
        let url = try TestImageFactory.makePNG(at: tempDir.appendingPathComponent("image.png"))
        switch FileValidator.validate(url: url) {
        case .success(let format):
            XCTAssertEqual(format, .png)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testRejectsNonImageFileWithGenericReason() throws {
        let url = tempDir.appendingPathComponent("notes.txt")
        try "just some text, not an image".write(to: url, atomically: true, encoding: .utf8)

        switch FileValidator.validate(url: url) {
        case .success:
            XCTFail("Expected failure for a non-image file")
        case .failure(let error):
            guard case .unsupportedFormat(let reason) = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
            XCTAssertEqual(reason, "This file format isn't supported")
        }
    }

    func testRejectsMissingFile() {
        let url = tempDir.appendingPathComponent("does-not-exist.png")
        switch FileValidator.validate(url: url) {
        case .success:
            XCTFail("Expected failure for a missing file")
        case .failure(let error):
            guard case .unsupportedFormat = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
        }
    }
}
