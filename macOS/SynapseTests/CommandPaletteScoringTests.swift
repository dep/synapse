import XCTest
@testable import Synapse

/// Tests for `commandPaletteScore(forURL:needle:relativePath:)`.
///
/// The scoring algorithm is the core of the command palette's file-ranking logic.
/// It ranks files across five tiers:
///
///   • Exact stem/filename match  → 200/190
///   • Prefix match on stem/filename/path  → 100/90/70
///   • Substring match on stem/filename/path  → 60/45/30
///   • Word-part multi-match  → 15 per matched word
///   • Depth penalty  → –2 per extra path component
///
/// A broken scoring function manifests as wrong files appearing at the top of
/// the palette, which makes the primary navigation shortcut unreliable for users.
final class CommandPaletteScoringTests: XCTestCase {

    // MARK: - Helpers

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/vault/\(name)")
    }

    // MARK: - Zero / no match

    func test_noMatch_returnsZero() {
        let score = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "xyz",
            relativePath: "readme.md"
        )
        XCTAssertEqual(score, 0, "Non-matching needle must yield zero")
    }

    func test_emptyNeedle_returnsZero() {
        let score = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "",
            relativePath: "readme.md"
        )
        XCTAssertEqual(score, 0, "Empty needle must yield zero (caller shows all files unscored)")
    }

    // MARK: - Exact stem match (200)

    func test_exactStemMatch_yields200() {
        let score = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "readme",
            relativePath: "readme.md"
        )
        XCTAssertEqual(score, 200, "Exact stem match must yield 200")
    }

    func test_exactStemMatch_caseInsensitive() {
        let score = commandPaletteScore(
            forURL: url("README.md"),
            needle: "readme",
            relativePath: "README.md"
        )
        XCTAssertEqual(score, 200, "Exact stem match should be case-insensitive")
    }

    // MARK: - Exact filename match (190)

    func test_exactFilenameMatch_yields190() {
        let score = commandPaletteScore(
            forURL: url("notes.txt"),
            needle: "notes.txt",
            relativePath: "notes.txt"
        )
        XCTAssertEqual(score, 190, "Exact filename match must yield 190")
    }

    // MARK: - Prefix matches

    func test_stemPrefixMatch_yields100() {
        let score = commandPaletteScore(
            forURL: url("readme-extended.md"),
            needle: "readme",
            relativePath: "readme-extended.md"
        )
        XCTAssertEqual(score, 100, "Stem prefix match must yield 100")
    }

    func test_filenamePrefixMatch_yields90() {
        // "notes" on notes.txt matches stem exactly → 200, not 90. Use different fixtures below.
        let score2 = commandPaletteScore(
            forURL: url("notes-v2.txt"),
            needle: "notes-v",
            relativePath: "notes-v2.txt"
        )
        // stem = "notes-v2", needle = "notes-v" — stem has prefix "notes-v" → 100
        XCTAssertEqual(score2, 100)

        // filename "notes-v2.txt" prefix with full extension included → 90
        let score3 = commandPaletteScore(
            forURL: url("notes-v2.txt"),
            needle: "notes-v2.t",
            relativePath: "notes-v2.txt"
        )
        XCTAssertEqual(score3, 90, "Filename prefix match (with extension) must yield 90")
    }

    func test_relativePathPrefixMatch_yields70_minusDepthPenalty() {
        // needle matches the beginning of the relative path but not just the filename
        let score = commandPaletteScore(
            forURL: url("folder/note.md"),
            needle: "folder/note",
            relativePath: "folder/note.md"
        )
        // "note" is the stem, "folder/note" doesn't match just the stem prefix,
        // but it does match the relativePath prefix → base score 70.
        // "folder/note.md" has depth 1 → penalty 2 → final score 68.
        XCTAssertEqual(score, 68, "Relative-path prefix match at depth 1 must yield 70 - 2 = 68")
    }

    // MARK: - Substring matches

    func test_stemSubstringMatch_yields60() {
        let score = commandPaletteScore(
            forURL: url("my-readme-file.md"),
            needle: "readme",
            relativePath: "my-readme-file.md"
        )
        XCTAssertEqual(score, 60, "Stem substring match must yield 60")
    }

    func test_filenameSubstringMatch_yields45() {
        // needle matches filename (with extension) but not just the stem
        let score = commandPaletteScore(
            forURL: url("note.backup"),
            needle: "backup",
            relativePath: "note.backup"
        )
        // stem = "note", filename = "note.backup"
        // "backup" not in stem, but "backup" in filename → 45
        XCTAssertEqual(score, 45, "Filename substring match must yield 45")
    }

    func test_relativePathSubstringMatch_yields30_minusDepthPenalty() {
        // Needle must appear in the path but NOT satisfy `relPath.hasPrefix(needle)` — that
        // branch scores 70 ("docs/index.md" + "docs" is a prefix match, not substring-only).
        let score = commandPaletteScore(
            forURL: url("a/docs/b.md"),
            needle: "docs",
            relativePath: "a/docs/b.md"
        )
        // stem = "b", filename = "b.md" — "docs" not in either; path contains "docs" → base 30.
        // depth = 2 (a/, docs/, b.md) → penalty 4 → final score 26.
        XCTAssertEqual(score, 26, "Relative-path substring-only match must be 30 minus depth penalty")
    }

    // MARK: - Word-part fallback (multi-word)

    func test_wordPartFallback_singleMatchingWord_yields15() {
        let score = commandPaletteScore(
            forURL: url("project-notes.md"),
            needle: "notes meeting",
            relativePath: "project-notes.md"
        )
        // stem "project-notes" contains "notes" but not "meeting" → 1 × 15 = 15
        XCTAssertEqual(score, 15, "One matching word part must yield 15")
    }

    func test_wordPartFallback_twoMatchingWords_yields30() {
        let score = commandPaletteScore(
            forURL: url("meeting-notes.md"),
            needle: "notes meeting",
            relativePath: "meeting-notes.md"
        )
        // stem "meeting-notes" contains both "notes" and "meeting" → 2 × 15 = 30
        XCTAssertEqual(score, 30, "Two matching word parts must yield 30")
    }

    func test_wordPartFallback_noMatchingWords_yieldsZero() {
        let score = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "alpha beta",
            relativePath: "readme.md"
        )
        XCTAssertEqual(score, 0, "No matching word parts must yield zero")
    }

    // MARK: - Depth penalty

    func test_depthPenalty_shallowFile_noExtraPenalty() {
        // Depth = 0 components → penalty = 0
        let score = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "readme",
            relativePath: "readme.md"
        )
        // Exact stem match → 200, depth of "readme.md" = 0 extra → 200 - 0 = 200
        XCTAssertEqual(score, 200)
    }

    func test_depthPenalty_oneLevel_deducts2() {
        // relativePath = "sub/readme.md" → depth = 1 → penalty = 2
        let score = commandPaletteScore(
            forURL: URL(fileURLWithPath: "/vault/sub/readme.md"),
            needle: "readme",
            relativePath: "sub/readme.md"
        )
        XCTAssertEqual(score, 198, "One extra path level must deduct 2 from the score")
    }

    func test_depthPenalty_twoLevels_deducts4() {
        let score = commandPaletteScore(
            forURL: URL(fileURLWithPath: "/vault/a/b/readme.md"),
            needle: "readme",
            relativePath: "a/b/readme.md"
        )
        XCTAssertEqual(score, 196, "Two extra path levels must deduct 4 from the score")
    }

    // MARK: - Ordering contracts

    func test_exactMatch_ranksHigherThanPrefixMatch() {
        let exact = commandPaletteScore(
            forURL: url("notes.md"),
            needle: "notes",
            relativePath: "notes.md"
        )
        let prefix = commandPaletteScore(
            forURL: url("notes-2024.md"),
            needle: "notes",
            relativePath: "notes-2024.md"
        )
        XCTAssertGreaterThan(exact, prefix, "Exact match must outrank a prefix match")
    }

    func test_prefixMatch_ranksHigherThanSubstringMatch() {
        let prefix = commandPaletteScore(
            forURL: url("readme-extended.md"),
            needle: "readme",
            relativePath: "readme-extended.md"
        )
        let substring = commandPaletteScore(
            forURL: url("my-readme-file.md"),
            needle: "readme",
            relativePath: "my-readme-file.md"
        )
        XCTAssertGreaterThan(prefix, substring, "Prefix match must outrank a substring match")
    }

    func test_shallowFile_ranksHigherThanDeepFile_whenSameTier() {
        let shallow = commandPaletteScore(
            forURL: url("readme.md"),
            needle: "readme",
            relativePath: "readme.md"
        )
        let deep = commandPaletteScore(
            forURL: URL(fileURLWithPath: "/vault/a/b/c/readme.md"),
            needle: "readme",
            relativePath: "a/b/c/readme.md"
        )
        XCTAssertGreaterThan(shallow, deep,
                             "A shallower file must rank higher than a deeper one for the same match tier")
    }
}
