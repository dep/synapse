import XCTest
@testable import Synapse

/// Tests for `FolderColor.palette` and `FolderIcon.set` — predefined folder customization options.
/// Regressions here break the folder appearance picker and corrupt stored settings keys.
final class FolderColorFolderIconPaletteTests: XCTestCase {

    func test_folderColor_palette_hasExpectedCount() {
        XCTAssertEqual(FolderColor.palette.count, 11, "Palette size is part of the product contract")
    }

    func test_folderColor_palette_idsAreUnique() {
        let ids = FolderColor.palette.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate color ids would collide in settings")
    }

    func test_folderColor_colorForKnownId() {
        XCTAssertEqual(FolderColor.color(for: "mint")?.id, "mint")
        XCTAssertEqual(FolderColor.color(for: "mint")?.label, "Mint")
    }

    func test_folderColor_colorForUnknownId_returnsNil() {
        XCTAssertNil(FolderColor.color(for: "nonexistent"))
    }

    func test_folderIcon_set_hasExpectedCount() {
        XCTAssertEqual(FolderIcon.set.count, 26, "Icon set size is part of the product contract")
    }

    func test_folderIcon_set_idsAreUnique() {
        let ids = FolderIcon.set.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate icon ids would collide in settings")
    }

    func test_folderIcon_iconForKnownId() {
        XCTAssertEqual(FolderIcon.icon(for: "moon")?.symbolName, "moon")
        XCTAssertEqual(FolderIcon.icon(for: "chart")?.symbolName, "chart.bar")
    }

    func test_folderIcon_iconForUnknownId_returnsNil() {
        XCTAssertNil(FolderIcon.icon(for: "nonexistent"))
    }
}
