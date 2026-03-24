import XCTest
@testable import Synapse

/// Tests for `MarkdownPreviewCSS.headingFontSize(level:baseSize:)` covering heading
/// levels 5 and 6, boundary behaviour with very small and very large base sizes,
/// and the guarantee that heading sizes are always positive integers.
///
/// The existing `MarkdownPreviewCSSTests` covers levels 1–4 with a single base size.
/// Levels 5 and 6 use different scale factors (1.0× and 0.93× respectively) and were
/// never tested.  A regression would make H5 and H6 tags render at a wrong size in
/// the HTML preview.
///
/// The clamp at the bottom (`max(12, ...)`) in the level-6 (default) branch is
/// also uncovered and is tested here.
final class MarkdownPreviewCSSHeadingTests: XCTestCase {

    // MARK: - Level 5 (1.0× base)

    func test_headingFontSize_level5_equalsBodyFontSize() {
        // Level 5 multiplier is 1.0; the result should equal the clamped body size.
        let base = 15
        let result = MarkdownPreviewCSS.headingFontSize(level: 5, baseSize: base)
        let body = MarkdownPreviewCSS.bodyFontSize(for: base)
        XCTAssertEqual(result, body,
                       "H5 should be rendered at the same size as the body text (1.0× multiplier)")
    }

    func test_headingFontSize_level5_smallBase_clampsBodyMin() {
        // baseSize=4 → bodyFontSize=8 → level5 = round(8*1.0) = 8
        let result = MarkdownPreviewCSS.headingFontSize(level: 5, baseSize: 4)
        XCTAssertEqual(result, 8,
                       "H5 with a sub-minimum base should use the clamped body size (8)")
    }

    func test_headingFontSize_level5_largeBase_scalesCorrectly() {
        let base = 24
        let expected = Int(round(CGFloat(MarkdownPreviewCSS.bodyFontSize(for: base)) * 1.0))
        XCTAssertEqual(MarkdownPreviewCSS.headingFontSize(level: 5, baseSize: base), expected)
    }

    // MARK: - Level 6 and default branch (0.93× base, min 12)

    func test_headingFontSize_level6_isLessThanLevel5() {
        let base = 15
        let h5 = MarkdownPreviewCSS.headingFontSize(level: 5, baseSize: base)
        let h6 = MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: base)
        XCTAssertLessThanOrEqual(h6, h5,
                                 "H6 should be smaller than or equal to H5")
    }

    func test_headingFontSize_level6_normalBase_scalesAt093() {
        let base = 15
        // bodyFontSize(15) = 15; 15 * 0.93 = 13.95 → round = 14; max(12, 14) = 14
        let expected = max(12, Int(round(CGFloat(MarkdownPreviewCSS.bodyFontSize(for: base)) * 0.93)))
        XCTAssertEqual(MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: base), expected)
    }

    func test_headingFontSize_level6_smallBase_clampsToTwelve() {
        // bodyFontSize(8) = 8; 8 * 0.93 = 7.44 → round = 7; max(12, 7) = 12
        let result = MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: 8)
        XCTAssertEqual(result, 12,
                       "H6 with a very small base should be clamped to 12pt minimum")
    }

    func test_headingFontSize_level6_largeBase_doesNotClamp() {
        // bodyFontSize(24) = 24; 24 * 0.93 = 22.32 → 22; max(12, 22) = 22
        let result = MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: 24)
        XCTAssertGreaterThan(result, 12,
                             "H6 with a large base should not be clamped to 12")
    }

    func test_headingFontSize_unknownLevel_usesLevel6Behaviour() {
        // The `default` case in the switch covers any level not 1–5.
        let level7 = MarkdownPreviewCSS.headingFontSize(level: 7, baseSize: 15)
        let level6 = MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: 15)
        XCTAssertEqual(level7, level6,
                       "Any level beyond 6 should use the same formula as level 6 (default branch)")
    }

    func test_headingFontSize_zeroLevel_usesDefaultBranch() {
        let result = MarkdownPreviewCSS.headingFontSize(level: 0, baseSize: 15)
        let level6 = MarkdownPreviewCSS.headingFontSize(level: 6, baseSize: 15)
        XCTAssertEqual(result, level6,
                       "level=0 falls through the switch default and should behave like level 6")
    }

    // MARK: - Hierarchy: all levels with same base form a descending-or-equal sequence

    func test_headingFontSizes_formDescendingHierarchyForLevels1Through6() {
        let base = 16
        var previous = Int.max
        for level in 1...6 {
            let size = MarkdownPreviewCSS.headingFontSize(level: level, baseSize: base)
            XCTAssertLessThanOrEqual(size, previous,
                "H\(level) (\(size)pt) should be ≤ H\(level - 1) (\(previous)pt)")
            previous = size
        }
    }

    func test_headingFontSizes_allPositive() {
        for level in 1...6 {
            for base in [4, 8, 12, 15, 18, 24] {
                let size = MarkdownPreviewCSS.headingFontSize(level: level, baseSize: base)
                XCTAssertGreaterThan(size, 0,
                    "headingFontSize(level: \(level), baseSize: \(base)) must be > 0, got \(size)")
            }
        }
    }

    // MARK: - Baseline regression: existing cases remain correct

    func test_headingFontSize_level1_baseSize15_returns28() {
        XCTAssertEqual(MarkdownPreviewCSS.headingFontSize(level: 1, baseSize: 15), 28,
                       "Regression guard: H1 at base 15 must be 28pt")
    }

    func test_headingFontSize_level4_baseSize15_returns16() {
        XCTAssertEqual(MarkdownPreviewCSS.headingFontSize(level: 4, baseSize: 15), 16,
                       "Regression guard: H4 at base 15 must be 16pt")
    }
}
