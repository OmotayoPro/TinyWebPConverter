import XCTest
@testable import TinyWebPCore

final class OutputPathResolverTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestImageFactory.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testReturnsPlainNameWhenNothingExists() {
        let url = OutputPathResolver.resolve(baseName: "photo", directory: tempDir)
        XCTAssertEqual(url.lastPathComponent, "photo.webp")
    }

    func testAutoRenamesOnCollision() throws {
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("photo.webp").path, contents: Data())

        let url = OutputPathResolver.resolve(baseName: "photo", directory: tempDir)
        XCTAssertEqual(url.lastPathComponent, "photo (1).webp")
    }

    func testIncrementsPastMultipleCollisions() throws {
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("photo.webp").path, contents: Data())
        FileManager.default.createFile(atPath: tempDir.appendingPathComponent("photo (1).webp").path, contents: Data())

        let url = OutputPathResolver.resolve(baseName: "photo", directory: tempDir)
        XCTAssertEqual(url.lastPathComponent, "photo (2).webp")
    }
}
