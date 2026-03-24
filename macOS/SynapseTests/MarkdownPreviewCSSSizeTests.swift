import XCTest
@testable import Synapse

/// Tests for the MarkdownPreviewCSS size-computation helpers that were not covered
/// by the existing MarkdownPreviewCSSTests:
///   - bodyFontSize(for:)   — body text clamped to ≥ 8
///   - tableFontSize(for:)  — table text clamped to ≥ 12 at base−1
///   - font-name escaping   — backslash and double-quote characters in custom
///                            font families must be escaped for CSS string literals
///
/// A regression in any of these would silently break the HTML preview's
/// typography for users with small font preferences or unusual font names.
final class MarkdownPreviewCSSSizeTests: XCTestCase {

    // MARK: - bodyFontSize

    func test_bodyFontSize_normalValue_returnsUnchanged() {
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 16), 16)
    }

    func test_bodyFontSize_exactMinimum_returnsEight() {
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 8), 8,
                       "8 is the lower bound and should be returned as-is")
    }

    func test_bodyFontSize_belowMinimum_clampsToEight() {
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 4), 8,
                       "Values below 8 should be clamped to 8")
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 0), 8,
                       "Zero should be clamped to 8")
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: -10), 8,
                       "Negative values should be clamped to 8")
    }

    func test_bodyFontSize_largeValue_returnsUnchanged() {
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 72), 72,
                       "Large font sizes should pass through unchanged")
    }

    func test_bodyFontSize_nineReturnsNine() {
        XCTAssertEqual(MarkdownPreviewCSS.bodyFontSize(for: 9), 9,
                       "9 is above the minimum and should be returned unchanged")
    }

    // MARK: - tableFontSize

    func test_tableFontSize_normalValue_returnsBaseMinus1() {
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 16), 15,
                       "Table font size should be one point below the body size")
    }

    func test_tableFontSize_exactMinimumInput_clampsTo12() {
        // With baseSize=13, base-1=12, which is the clamp floor.
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 13), 12)
    }

    func test_tableFontSize_smallInput_clampsTo12() {
        // base-1 for baseSize=8 is 7, but clamp floor is 12.
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 8), 12,
                       "Values that produce a table size below 12 should be clamped to 12")
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 4), 12)
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 0), 12)
    }

    func test_tableFontSize_inputOf14_returns13() {
        // 14 - 1 = 13, which is above the clamp floor of 12.
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 14), 13)
    }

    func test_tableFontSize_largeValue_tracksBase() {
        XCTAssertEqual(MarkdownPreviewCSS.tableFontSize(for: 24), 23)
    }

    func test_tableFontSize_isAlwaysLessThanOrEqualToBodyFontSize() {
        for base in [8, 12, 14, 16, 20, 24] {
            let table = MarkdownPreviewCSS.tableFontSize(for: base)
            let body = MarkdownPreviewCSS.bodyFontSize(for: base)
            XCTAssertLessThanOrEqual(table, body,
                "tableFontSize should never exceed bodyFontSize (base=\(base))")
        }
    }

    // MARK: - Font-name escaping (via bodyFontStack / monoFontStack)

    func test_bodyFontStack_fontNameWithBackslash_escapesBackslash() {
        let stack = MarkdownPreviewCSS.bodyFontStack(for: #"Back\Slash"#)
        XCTAssertTrue(stack.contains(#"\\"#),
                      "A backslash in a font family name must be escaped as \\\\ in CSS")
    }

    func test_bodyFontStack_fontNameWithDoubleQuote_escapesQuote() {
        let stack = MarkdownPreviewCSS.bodyFontStack(for: #"Font "Name""#)
        XCTAssertTrue(stack.contains(#"\""#),
                      "A double-quote in a font family name must be escaped as \\\" in CSS")
    }

    func test_monoFontStack_fontNameWithBackslash_escapesBackslash() {
        let stack = MarkdownPreviewCSS.monoFontStack(for: #"Mono\Font"#)
        XCTAssertTrue(stack.contains(#"\\"#),
                      "A backslash in a mono font family name must be escaped as \\\\")
    }

    func test_monoFontStack_fontNameWithDoubleQuote_escapesQuote() {
        let stack = MarkdownPreviewCSS.monoFontStack(for: #"Mono "Code""#)
        XCTAssertTrue(stack.contains(#"\""#),
                      "A double-quote in a mono font family name must be escaped as \\\"")
    }

    func test_bodyFontStack_normalFontName_noEscaping() {
        let stack = MarkdownPreviewCSS.bodyFontStack(for: "Chalkboard SE")
        XCTAssertEqual(stack, "\"Chalkboard SE\", sans-serif",
                       "A normal font name should not have extra escaping applied")
    }

    func test_bodyFontStack_fontNameWithBothSpecialChars_escapesBoth() {
        let stack = MarkdownPreviewCSS.bodyFontStack(for: #"Font\"Name"#)
        XCTAssertTrue(stack.contains(#"\\"#), "Backslash should be escaped")
        XCTAssertTrue(stack.contains(#"\""#), "Double-quote should be escaped")
    }

    // MARK: - lineHeight upper clamp

    func test_lineHeight_aboveUpperClamp_clampsToThree() {
        XCTAssertEqual(MarkdownPreviewCSS.lineHeight(for: 5.0), 3.0, accuracy: 0.001,
                       "Values above 3.0 should be clamped to 3.0")
        XCTAssertEqual(MarkdownPreviewCSS.lineHeight(for: 3.1), 3.0, accuracy: 0.001)
    }

    func test_lineHeight_exactUpperBound_returnsThree() {
        XCTAssertEqual(MarkdownPreviewCSS.lineHeight(for: 3.0), 3.0, accuracy: 0.001)
    }

    func test_lineHeight_exactLowerBound_returnsPointEight() {
        XCTAssertEqual(MarkdownPreviewCSS.lineHeight(for: 0.8), 0.8, accuracy: 0.001)
    }
}
