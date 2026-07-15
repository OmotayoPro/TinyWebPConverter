import XCTest
@testable import TinyWebPCore

final class ResizeOptionTests: XCTestCase {
    let original = CGSize(width: 200, height: 100)

    func testNoneReturnsOriginalSize() {
        XCTAssertEqual(ResizeOption.none.targetSize(for: original), original)
    }

    func testPercentageScalesBothDimensions() {
        let size = ResizeOption.percentage(50).targetSize(for: original)
        XCTAssertEqual(size, CGSize(width: 100, height: 50))
    }

    func testWidthOnlyPreservesAspectRatio() {
        let size = ResizeOption.dimensions(width: 100, height: nil).targetSize(for: original)
        XCTAssertEqual(size, CGSize(width: 100, height: 50))
    }

    func testHeightOnlyPreservesAspectRatio() {
        let size = ResizeOption.dimensions(width: nil, height: 25).targetSize(for: original)
        XCTAssertEqual(size, CGSize(width: 50, height: 25))
    }

    func testBothDimensionsIgnoresAspectRatio() {
        let size = ResizeOption.dimensions(width: 10, height: 10).targetSize(for: original)
        XCTAssertEqual(size, CGSize(width: 10, height: 10))
    }

    func testBlankDimensionsReturnsOriginalSize() {
        let size = ResizeOption.dimensions(width: nil, height: nil).targetSize(for: original)
        XCTAssertEqual(size, original)
    }
}
