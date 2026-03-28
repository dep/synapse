import XCTest
@testable import Synapse

/// Tests for MarkdownTablePrettifier — the engine that re-formats raw
/// Markdown pipe-tables into aligned columns and adjusts the cursor offset.
///
/// This is critical functionality: every Tab keypress inside a table goes
/// through this code. A regression here silently corrupts table content or
/// drops the cursor to a wrong position.
final class MarkdownTablePrettifierTests: XCTestCase {

    // MARK: - Basic prettification

    func test_prettify_simpleTable_producesEquallyPaddedColumns() {
        let input = "| A | B |\n| --- | --- |\n| x | yy |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let expected = "| A  | B  |\n| --- | --- |\n| x  | yy |\n"
        XCTAssertEqual(result?.formatted, expected)
    }

    func test_prettify_preservesTrailingNewline_whenInputHasOne() {
        let input = "| A | B |\n| --- | --- |\n| x | yy |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertTrue(result?.formatted.hasSuffix("\n") ?? false)
    }

    func test_prettify_noTrailingNewline_outputHasNoTrailingNewline() {
        let input = "| A | B |\n| --- | --- |\n| x | yy |"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.formatted.hasSuffix("\n"))
    }

    /// GitHub Actions checks out with LF, but editors on Windows use CRLF; prettify must accept both.
    func test_prettify_normalizesCRLF() {
        let input = "| A | B |\r\n| --- | --- |\r\n| x | yy |\r\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.formatted, "| A  | B  |\n| --- | --- |\n| x  | yy |\n")
    }

    // MARK: - Separator row handling

    func test_prettify_leftAligned_separatorHasNoPrefixOrSuffixColon() {
        let input = "| L | R |\n| --- | --- |\n| a | b |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let lines = result!.formatted.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
        XCTAssertEqual(lines[1], "| --- | --- |")
    }

    func test_prettify_rightAligned_separatorHasSuffixColon() {
        let input = "| L | R |\n| --- | ---: |\n| a | b |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let lines = result!.formatted.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
        XCTAssertEqual(lines[1], "| --- | ---: |")
    }

    func test_prettify_centerAligned_separatorHasBothColons() {
        let input = "| L | R |\n| :---: | :---: |\n| a | b |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let lines = result!.formatted.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
        XCTAssertEqual(lines[1], "| :---: | :---: |")
    }

    // MARK: - Minimum column width

    func test_prettify_shortContent_columnWidthAtLeast3() {
        let input = "| a | b |\n| - | - |\n| x | y |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let sepLine = result!.formatted
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: "\n")[1]
        XCTAssertTrue(sepLine.contains("---"), "Separator should use at least three dashes per column: \(sepLine)")
    }

    // MARK: - Guard / nil cases

    func test_prettify_onlyOneRow_returnsNil() {
        let input = "| Col |\n"

        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNil(result, "A table with only a header row (no separator) must not be prettified")
    }

    func test_prettify_missingSeparatorRow_returnsNil() {
        let input = "| Col |\n| NotASeparator |\n"

        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNil(result, "A table without a valid separator row must not be prettified")
    }

    func test_prettify_emptyString_returnsNil() {
        let result = MarkdownTablePrettifier.prettify(tableText: "", cursorOffsetInTable: 0)

        XCTAssertNil(result, "Prettifying an empty string must return nil")
    }

    // MARK: - Cell parsing

    func test_parseCells_leadingAndTrailingPipes_stripsExactlyOne() {
        let cells = MarkdownTablePrettifier.parseCells(from: "| Alpha | Beta |")

        XCTAssertEqual(cells.count, 2, "Should parse 2 cells from a 2-column row — got: \(cells)")
        XCTAssertEqual(cells[0].trimmingCharacters(in: .whitespaces), "Alpha")
        XCTAssertEqual(cells[1].trimmingCharacters(in: .whitespaces), "Beta")
    }

    func test_parseCells_noPipes_returnsSingleCell() {
        let cells = MarkdownTablePrettifier.parseCells(from: "NoPipes")

        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(cells[0], "NoPipes")
    }

    func test_parseCells_emptyString_returnsSingleEmptyString() {
        let cells = MarkdownTablePrettifier.parseCells(from: "")

        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(cells[0], "")
    }

    // MARK: - Cursor adjustment

    func test_prettify_cursorAtColumnBoundary_staysWithinFormattedLength() {
        let input = "| A | B |\n| --- | --- |\n| x | yy |\n"
        let formattedLen = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)!.formatted.count

        for offset in stride(from: 0, to: input.count, by: 3) {
            let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: offset)
            XCTAssertNotNil(result)
            XCTAssertGreaterThanOrEqual(result!.cursorOffset, 0)
            XCTAssertLessThanOrEqual(result!.cursorOffset, formattedLen)
        }
    }

    func test_prettify_cursorAtZero_returnsNonNegativeOffset() {
        let input = "| A | B |\n| --- | --- |\n| x | yy |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.cursorOffset, 0)
    }

    // MARK: - Multi-column alignment mix

    func test_prettify_multipleAlignments_allRowsHaveSameColumnCount() {
        let input = "| L | C | R |\n| :-- | :-: | --: |\n| a | bb | ccc |\n"
        let result = MarkdownTablePrettifier.prettify(tableText: input, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        let lines = result!.formatted.trimmingCharacters(in: .newlines).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        for line in lines {
            let pipeCount = line.filter { $0 == "|" }.count
            XCTAssertEqual(pipeCount, 4, "Each row should have 4 pipe characters (3 columns): \(line)")
        }
    }

    // MARK: - PrettifyResult properties

    func test_prettifyResult_formattedIsDifferentFromRawWhenInputIsUnaligned() {
        let raw = "|A|BB|\n|---|---|\n|x|y|\n"
        let result = MarkdownTablePrettifier.prettify(tableText: raw, cursorOffsetInTable: 0)

        XCTAssertNotNil(result)
        XCTAssertNotEqual(result!.formatted, raw)
    }
}
