import XCTest
import AppKit
@testable import Synapse

/// Tests for applyPreviewStyling() — verifies that markdown syntax tokens are hidden
/// and that fenced code blocks only hide fences for complete (matched) pairs.
final class PreviewModeTests: XCTestCase {

    var textView: LinkAwareTextView!

    override func setUp() {
        super.setUp()
        textView = LinkAwareTextView()
        textView.isEditable = false
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
    }

    override func tearDown() {
        textView = nil
        super.tearDown()
    }

    /// Returns true if the character at `index` in the text storage has a clear/hidden foreground color.
    private func isHidden(at index: Int) -> Bool {
        guard let storage = textView.textStorage, index < storage.length else { return false }
        if let color = storage.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor {
            return color.alphaComponent < 0.01
        }
        // Font size near-zero is the other hide mechanism
        if let font = storage.attribute(.font, at: index, effectiveRange: nil) as? NSFont {
            return font.pointSize < 0.1
        }
        return false
    }

    /// Returns true if every character in `range` of the text storage is hidden.
    private func allHidden(in range: NSRange) -> Bool {
        guard let storage = textView.textStorage else { return false }
        for i in range.location ..< (range.location + range.length) {
            guard i < storage.length else { return false }
            if !isHidden(at: i) { return false }
        }
        return true
    }

    /// Returns true if at least one character in `range` is NOT hidden.
    private func anyVisible(in range: NSRange) -> Bool {
        guard let storage = textView.textStorage else { return false }
        for i in range.location ..< (range.location + range.length) {
            guard i < storage.length else { continue }
            if !isHidden(at: i) { return true }
        }
        return false
    }

    // MARK: - Syntax token hiding

    func test_headingHash_isHiddenInPreview() {
        textView.setPlainText("# Heading One")
        textView.applyPreviewStyling()

        // The "# " prefix (first 2 chars) should be hidden
        XCTAssertTrue(allHidden(in: NSRange(location: 0, length: 2)), "ATX heading '# ' prefix should be hidden in preview")
        // The heading text itself should be visible
        XCTAssertTrue(anyVisible(in: NSRange(location: 2, length: 11)), "Heading text should remain visible in preview")
    }

    func test_boldDelimiters_areHiddenInPreview() {
        let text = "Hello **world** end"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        let ns = text as NSString
        // "**" before "world" at index 6
        let openRange = NSRange(location: 6, length: 2)
        // "**" after "world" at index 13
        let closeRange = NSRange(location: 13, length: 2)

        XCTAssertTrue(allHidden(in: openRange), "Opening ** should be hidden in preview")
        XCTAssertTrue(allHidden(in: closeRange), "Closing ** should be hidden in preview")
        // "world" (index 8–12) should be visible
        XCTAssertTrue(anyVisible(in: NSRange(location: 8, length: 5)), "Bold content should remain visible")
    }

    func test_inlineCodeBackticks_areHiddenInPreview() {
        let text = "Use `func()` here"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        let ns = text as NSString
        // Opening backtick at index 4
        XCTAssertTrue(isHidden(at: 4), "Opening backtick should be hidden in preview")
        // Closing backtick at index 11
        XCTAssertTrue(isHidden(at: 11), "Closing backtick should be hidden in preview")
        // "func()" content should be visible
        XCTAssertTrue(anyVisible(in: NSRange(location: 5, length: 6)), "Inline code content should remain visible")
    }

    func test_blockquotePrefix_isHiddenInPreview() {
        let text = "> A blockquote"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        // "> " prefix (2 chars)
        XCTAssertTrue(allHidden(in: NSRange(location: 0, length: 2)), "Blockquote '> ' prefix should be hidden")
        XCTAssertTrue(anyVisible(in: NSRange(location: 2, length: 12)), "Blockquote content should remain visible")
    }

    // MARK: - Fenced code block fence visibility

    func test_completeFencePair_bothFencesAreHidden() {
        let text = "```\nhello code\n```"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        // Opening fence "```" at index 0–2
        XCTAssertTrue(allHidden(in: NSRange(location: 0, length: 3)), "Opening ``` of a complete pair should be hidden")
        // Closing fence "```" at index 15–17
        let closingFenceStart = (text as NSString).range(of: "```", options: [], range: NSRange(location: 4, length: text.count - 4)).location
        XCTAssertTrue(allHidden(in: NSRange(location: closingFenceStart, length: 3)), "Closing ``` of a complete pair should be hidden")
    }

    func test_unclosedFence_remainsVisible() {
        let text = "```\nhello code\nno closing fence"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        // Opening fence "```" at index 0 should NOT be hidden (no matching close)
        XCTAssertFalse(allHidden(in: NSRange(location: 0, length: 3)), "Unclosed ``` should remain visible so the user knows it is open")
    }

    func test_twoPairs_allFencesHidden() {
        let text = "```\nfirst block\n```\nsome text\n```\nsecond block\n```"
        textView.setPlainText(text)
        textView.applyPreviewStyling()

        // Both opening fences should be hidden
        // First opening at 0
        XCTAssertTrue(allHidden(in: NSRange(location: 0, length: 3)), "First opening fence should be hidden")
        // Second opening — find it
        let ns = text as NSString
        let secondOpenRange = ns.range(of: "```", options: [], range: NSRange(location: 20, length: ns.length - 20))
        XCTAssertTrue(allHidden(in: NSRange(location: secondOpenRange.location, length: 3)), "Second opening fence should be hidden")
    }
}
