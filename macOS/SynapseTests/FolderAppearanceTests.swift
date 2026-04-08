import XCTest
import SwiftUI
@testable import Synapse

/// Tests for per-folder color/icon customization: palette lookup, resolved values, and Codable portability.
final class FolderAppearanceTests: XCTestCase {

    // MARK: - FolderColor.palette

    func test_folderColor_paletteHasElevenEntries() {
        XCTAssertEqual(FolderColor.palette.count, 11)
    }

    func test_folderColor_paletteIdsAreUnique() {
        let ids = FolderColor.palette.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_folderColor_colorForKnownId_returnsMatch() {
        let rose = FolderColor.color(for: "rose")
        XCTAssertNotNil(rose)
        XCTAssertEqual(rose?.id, "rose")
        XCTAssertEqual(rose?.label, "Rose")
    }

    func test_folderColor_colorForUnknownId_returnsNil() {
        XCTAssertNil(FolderColor.color(for: "not-a-real-folder-color"))
    }

    // MARK: - FolderIcon.set

    func test_folderIcon_setHasExpectedCount() {
        XCTAssertEqual(FolderIcon.set.count, 27)
    }

    func test_folderIcon_setIdsAreUnique() {
        let ids = FolderIcon.set.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_folderIcon_iconForKnownId_returnsMatch() {
        let star = FolderIcon.icon(for: "star")
        XCTAssertNotNil(star)
        XCTAssertEqual(star?.symbolName, "star")
    }

    func test_folderIcon_iconForUnknownId_returnsNil() {
        XCTAssertNil(FolderIcon.icon(for: "unknown-icon-key"))
    }

    // MARK: - FolderAppearance resolved values

    func test_folderAppearance_resolvedColor_nilWhenNoKey() {
        let sut = FolderAppearance(relativePath: "Work", colorKey: nil, iconKey: nil)
        XCTAssertNil(sut.resolvedColor)
    }

    func test_folderAppearance_resolvedColor_nonNilForValidKey() {
        let sut = FolderAppearance(relativePath: "Work", colorKey: "mint", iconKey: nil)
        XCTAssertNotNil(sut.resolvedColor)
    }

    func test_folderAppearance_resolvedSymbolName_nilWhenNoKey() {
        let sut = FolderAppearance(relativePath: "Work", colorKey: nil, iconKey: nil)
        XCTAssertNil(sut.resolvedSymbolName)
    }

    func test_folderAppearance_resolvedSymbolName_nonNilForValidKey() {
        let sut = FolderAppearance(relativePath: "Work", colorKey: nil, iconKey: "book")
        XCTAssertEqual(sut.resolvedSymbolName, "book.closed")
    }

    func test_folderAppearance_idMatchesRelativePath() {
        let sut = FolderAppearance(relativePath: "Projects/Notes", colorKey: "sky", iconKey: "moon")
        XCTAssertEqual(sut.id, "Projects/Notes")
    }

    // MARK: - FolderAppearance Codable

    func test_folderAppearance_encodesAndDecodes() throws {
        let original = FolderAppearance(
            relativePath: "Archive/2024",
            colorKey: "lavender",
            iconKey: "calendar"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FolderAppearance.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_folderAppearance_decodeMissingOptionalKeys_defaultsToNil() throws {
        let json = """
        {"relativePath":"OnlyPath"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(FolderAppearance.self, from: json)
        XCTAssertEqual(decoded.relativePath, "OnlyPath")
        XCTAssertNil(decoded.colorKey)
        XCTAssertNil(decoded.iconKey)
    }
}
