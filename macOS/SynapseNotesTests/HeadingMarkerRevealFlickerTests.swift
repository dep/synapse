import XCTest
import AppKit
@testable import Synapse

/// Tests for the "heading markers blink out while typing" flicker.
///
/// In `hideMarkdownWhileEditing` mode, `applyPreviewStyling` is a pure "hide
/// everything" sweep: it zeroes every markdown token to `systemFont(0.001)` +
/// clear color, *including the `###` on the line the caret is on*. Re-revealing
/// the caret's block used to be left to the separate, independently debounced
/// selection-change work item. So the typing path
/// (`applyMarkdownStyling` -> `applyPreviewStyling`) committed a frame in which
/// the active line's own markers were invisible — the split-second disappearance.
///
/// The fix re-reveals the caret's block inside the same styling pass, and uses
/// `deferRedraw` so the intermediate hidden state never reaches the screen.
///
/// The invariant these tests pin: after a full styling pass, the markers on the
/// caret's own line are visible — never the near-zero hidden font.
final class HeadingMarkerRevealFlickerTests: XCTestCase {

    // MARK: - Helpers

    /// An editable text view with the caret placed inside `caretMarker`'s match.
    private func makeTextView(string: String, caretInside caretMarker: String) -> LinkAwareTextView {
        let tv = LinkAwareTextView()
        tv.isEditable = true
        tv.string = string
        let range = (string as NSString).range(of: caretMarker)
        XCTAssertTrue(range.location != NSNotFound, "caret anchor \(caretMarker.debugDescription) must exist")
        tv.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        return tv
    }

    /// Reproduces the editor's typing path for hide-markdown mode.
    private func runTypingStylingPass(_ tv: LinkAwareTextView) {
        let document = MarkdownDocumentParser().parse(tv.string)
        let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        tv.applyMarkdownStyling(document: document, deferRedraw: true)
        tv.applyPreviewStyling(document: document, editingSessionOpen: true, deferRedraw: true)
        tv.invalidateRevealedBlock()
        tv.revealCurrentBlockMarkdownAtCursor(document: document, fallbackRedrawRange: fullRange)
    }

    /// Hidden tokens are set to `systemFont(ofSize: 0.001)`; anything at a normal
    /// size is visible on screen.
    private func assertVisible(
        _ token: String,
        in tv: LinkAwareTextView,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let storage = tv.textStorage else {
            return XCTFail("no storage", file: file, line: line)
        }
        let range = (tv.string as NSString).range(of: token)
        XCTAssertTrue(range.location != NSNotFound, "\(token.debugDescription) must be in string", file: file, line: line)
        let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        let color = storage.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
        XCTAssertGreaterThan(font?.pointSize ?? 0, 1.0, message, file: file, line: line)
        XCTAssertNotEqual(color, NSColor.clear, message, file: file, line: line)
    }

    private func assertHidden(
        _ token: String,
        in tv: LinkAwareTextView,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let storage = tv.textStorage else {
            return XCTFail("no storage", file: file, line: line)
        }
        let range = (tv.string as NSString).range(of: token)
        XCTAssertTrue(range.location != NSNotFound, "\(token.debugDescription) must be in string", file: file, line: line)
        let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        XCTAssertLessThan(font?.pointSize ?? 99, 1.0, message, file: file, line: line)
    }

    // MARK: - The caret's own heading markers stay visible

    /// Primary regression test: this is the `###` the user watched disappear.
    func test_h3Markers_onCaretLine_remainVisibleAfterTypingStylingPass() {
        let tv = makeTextView(string: "### Section title\n\nBody text.", caretInside: "Section")
        runTypingStylingPass(tv)

        assertVisible("### ", in: tv,
                      message: "the ### on the caret's own line must stay visible through the styling pass")
    }

    func test_headingMarkers_onCaretLine_remainVisible_atEveryLevel() {
        for marker in ["# ", "## ", "### ", "#### ", "##### ", "###### "] {
            let tv = makeTextView(string: "\(marker)Title\n\nBody.", caretInside: "Title")
            runTypingStylingPass(tv)
            assertVisible(marker, in: tv,
                          message: "\(marker.debugDescription) on the caret's line must stay visible")
        }
    }

    /// The caret sitting right after the marker (as when you've just typed `"### "`)
    /// is the exact moment the flicker was reported.
    func test_bareHeadingMarker_withCaretAtEndOfLine_remainsVisible() {
        let tv = LinkAwareTextView()
        tv.isEditable = true
        tv.string = "### "
        tv.setSelectedRange(NSRange(location: 4, length: 0))

        runTypingStylingPass(tv)

        assertVisible("### ", in: tv,
                      message: "a just-typed bare '### ' must not blink out from under the caret")
    }

    // MARK: - Hiding still works where it should

    /// The fix must not turn hide-markdown mode off: a heading the caret is *not*
    /// on still gets its markers hidden.
    func test_headingMarkers_onOtherLines_areStillHidden() {
        let tv = makeTextView(string: "# First\n\n## Second\n\nBody text.", caretInside: "Body")
        runTypingStylingPass(tv)

        assertHidden("# ", in: tv, message: "a heading the caret is not on must stay hidden")
        assertHidden("## ", in: tv, message: "a heading the caret is not on must stay hidden")
    }

    /// Moving the caret between two headings must re-hide the one it left and
    /// reveal the one it entered.
    func test_movingCaretBetweenHeadings_swapsWhichMarkersAreVisible() {
        let markdown = "# First heading\n\n## Second heading\n\nBody."
        let ns = markdown as NSString

        let tv = LinkAwareTextView()
        tv.isEditable = true
        tv.string = markdown

        tv.setSelectedRange(NSRange(location: ns.range(of: "First").location + 1, length: 0))
        runTypingStylingPass(tv)
        assertVisible("# ", in: tv, message: "caret is on the H1, its marker must be visible")
        assertHidden("## ", in: tv, message: "the H2 the caret is not on must be hidden")

        tv.setSelectedRange(NSRange(location: ns.range(of: "Second").location + 1, length: 0))
        runTypingStylingPass(tv)
        assertVisible("## ", in: tv, message: "caret moved to the H2, its marker must now be visible")
    }

    // MARK: - Heading font is preserved through the reveal

    /// The reveal restores a *body-sized* font on the marker so the glyphs read
    /// cleanly, but the heading's content must keep its heading font — otherwise
    /// revealing would itself resize the line.
    func test_headingContent_keepsHeadingFont_whenMarkersAreRevealed() {
        let tv = makeTextView(string: "### Section title\n\nBody.", caretInside: "Section")
        runTypingStylingPass(tv)

        guard let storage = tv.textStorage else { return XCTFail("no storage") }
        let contentLocation = (tv.string as NSString).range(of: "Section").location
        let bodyLocation = (tv.string as NSString).range(of: "Body.").location

        let contentFont = storage.attribute(.font, at: contentLocation, effectiveRange: nil) as? NSFont
        let bodyFont = storage.attribute(.font, at: bodyLocation, effectiveRange: nil) as? NSFont

        XCTAssertGreaterThan(
            contentFont?.pointSize ?? 0, bodyFont?.pointSize ?? 0,
            "revealing the ### must not shrink the heading text to body size"
        )
    }
}
