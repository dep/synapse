import XCTest
@testable import Synapse

/// Tests for `MiniBrowserController` URL normalization and loading entry points.
@MainActor
final class MiniBrowserControllerTests: XCTestCase {

    func test_load_blankInput_leavesURLTextEmpty() {
        let sut = MiniBrowserController()
        XCTAssertEqual(sut.urlText, "")
        sut.load("   \n")
        XCTAssertEqual(sut.urlText, "")
    }

    func test_load_invalidInput_leavesURLTextEmpty() {
        let sut = MiniBrowserController()
        sut.load("@@@")
        XCTAssertEqual(sut.urlText, "")
    }

    func test_load_appliesHTTPSForBareHost() {
        let sut = MiniBrowserController()
        sut.load("example.com")
        XCTAssertEqual(sut.urlText, "https://example.com")
    }

    func test_load_trimsWhitespaceAroundURL() {
        let sut = MiniBrowserController()
        sut.load("  dep.dev  ")
        XCTAssertEqual(sut.urlText, "https://dep.dev")
    }
}
