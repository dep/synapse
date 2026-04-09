import XCTest
@testable import Synapse

/// Tests for `commandPaletteScoreByFolderName(forURL:needle:)`.
///
/// Folder results in the command palette rank by folder name only (not full path).
/// Tiers mirror filename scoring: exact 200, prefix 100, substring 60.
final class CommandPaletteFolderScoringTests: XCTestCase {

    private func folderURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/vault/projects/\(name)", isDirectory: true)
    }

    func test_emptyNeedle_returnsZero() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("Work"), needle: ""),
            0
        )
    }

    func test_noMatch_returnsZero() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("Work"), needle: "zzz"),
            0
        )
    }

    func test_exactFolderNameMatch_yields200() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("Work"), needle: "work"),
            200
        )
    }

    func test_exactMatch_isCaseInsensitive() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("Research"), needle: "research"),
            200
        )
    }

    func test_prefixMatch_yields100() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("WorkNotes"), needle: "work"),
            100
        )
    }

    func test_substringMatch_yields60() {
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: folderURL("my-archive"), needle: "arch"),
            60
        )
    }

    func test_pathDoesNotAffectScore_sameNameDifferentParents() {
        let a = URL(fileURLWithPath: "/vault/a/Notes", isDirectory: true)
        let b = URL(fileURLWithPath: "/other/b/Notes", isDirectory: true)
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: a, needle: "notes"),
            commandPaletteScoreByFolderName(forURL: b, needle: "notes")
        )
    }

    func test_parentPathDoesNotMatch_needle() {
        let url = URL(fileURLWithPath: "/vault/Projects/Work", isDirectory: true)
        XCTAssertEqual(
            commandPaletteScoreByFolderName(forURL: url, needle: "projects"),
            0,
            "Only the folder name (last path component) participates in scoring"
        )
    }

    func test_exactOutranksPrefix() {
        let exact = commandPaletteScoreByFolderName(forURL: folderURL("dev"), needle: "dev")
        let prefix = commandPaletteScoreByFolderName(forURL: folderURL("development"), needle: "dev")
        XCTAssertGreaterThan(exact, prefix)
    }

    func test_prefixOutranksSubstring() {
        let prefix = commandPaletteScoreByFolderName(forURL: folderURL("dev-tools"), needle: "dev")
        let substring = commandPaletteScoreByFolderName(forURL: folderURL("foo-dev-bar"), needle: "dev")
        XCTAssertGreaterThan(prefix, substring)
    }
}
