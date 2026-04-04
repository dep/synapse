import XCTest
import SwiftUI
@testable import Synapse

/// Tests for `FolderAppearance` — per-folder color/icon settings stored relative to vault root.
/// Incorrect encoding or resolution breaks the file tree and settings portability.
final class FolderAppearanceTests: XCTestCase {

    func test_codable_roundTrip_preservesAllFields() throws {
        let original = FolderAppearance(
            relativePath: "Projects/Work",
            colorKey: "teal",
            iconKey: "bookmark"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FolderAppearance.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.id, "Projects/Work")
    }

    func test_codable_roundTrip_nilOptionalKeys() throws {
        let original = FolderAppearance(relativePath: "Inbox", colorKey: nil, iconKey: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FolderAppearance.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.colorKey)
        XCTAssertNil(decoded.iconKey)
    }

    func test_resolvedColor_knownKey_returnsSwiftUIColor() {
        let sut = FolderAppearance(relativePath: "x", colorKey: "rose", iconKey: nil)
        XCTAssertNotNil(sut.resolvedColor)
    }

    func test_resolvedColor_unknownKey_returnsNil() {
        let sut = FolderAppearance(relativePath: "x", colorKey: "not-a-real-palette-id", iconKey: nil)
        XCTAssertNil(sut.resolvedColor)
    }

    func test_resolvedColor_nilKey_returnsNil() {
        let sut = FolderAppearance(relativePath: "x", colorKey: nil, iconKey: "star")
        XCTAssertNil(sut.resolvedColor)
    }

    func test_resolvedSymbolName_knownKey_returnsSFSymbolName() {
        let sut = FolderAppearance(relativePath: "x", colorKey: nil, iconKey: "book")
        XCTAssertEqual(sut.resolvedSymbolName, "book.closed")
    }

    func test_resolvedSymbolName_unknownKey_returnsNil() {
        let sut = FolderAppearance(relativePath: "x", colorKey: "rose", iconKey: "not-an-icon")
        XCTAssertNil(sut.resolvedSymbolName)
    }

    func test_resolvedSymbolName_nilKey_returnsNil() {
        let sut = FolderAppearance(relativePath: "x", colorKey: "rose", iconKey: nil)
        XCTAssertNil(sut.resolvedSymbolName)
    }
}
