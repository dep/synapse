import XCTest
@testable import Synapse

/// Tests for MarkdownTablePrettifier — column alignment and cursor mapping for Format Table.
final class MarkdownTablePrettifierTests: XCTestCase {

    func test_prettify_nilWhenTooFewLines() {
        XCTAssertNil(MarkdownTablePrettifier.prettify(tableText: "| a |", cursorOffsetInTable: 0))
        XCTAssertNil(MarkdownTablePrettifier.prettify(tableText: "| a |\n", cursorOffsetInTable: 0))
    }

    func test_prettify_nilWhenSeparatorRowInvalid() {
        let text = """
        | a | b |
        | x | y |
        """
        XCTAssertNil(MarkdownTablePrettifier.prettify(tableText: text, cursorOffsetInTable: 0))
    }

    func test_parseCells_trimsOuterPipes() {
        XCTAssertEqual(MarkdownTablePrettifier.parseCells(from: "| a | b |"), [" a ", " b "])
        XCTAssertEqual(MarkdownTablePrettifier.parseCells(from: "a|b"), ["a", "b"])
    }

    func test_prettify_alignsColumnsAndPreservesTrailingNewline() {
        let text = "|a|bb|\n|---|---|\n|x|y|\n"
        guard let result = MarkdownTablePrettifier.prettify(tableText: text, cursorOffsetInTable: 0) else {
            return XCTFail("Expected prettify to succeed")
        }
        XCTAssertTrue(result.formatted.hasSuffix("\n"), "Should keep trailing newline when input had one")
        XCTAssertTrue(result.formatted.contains("| a  | bb |"))
        XCTAssertTrue(result.formatted.contains("| --- | --- |"))
        XCTAssertTrue(result.formatted.contains("| x  | y  |"))
    }

    func test_prettify_rightAndCenterAlignmentInSeparator() {
        let text = """
        |L|C|R|
        |:--|:-:|--:|
        |1|2|3|
        """
        guard let result = MarkdownTablePrettifier.prettify(tableText: text, cursorOffsetInTable: 0) else {
            return XCTFail("Expected prettify to succeed")
        }
        XCTAssertTrue(result.formatted.contains(":---"), "Left-aligned separator should use :--- style")
        XCTAssertTrue(result.formatted.contains(":---:"), "Center column should use :---: in separator row")
        XCTAssertTrue(result.formatted.contains("---:"), "Right-aligned column should end with ---:")
    }
}
