import XCTest
import AppKit
@testable import Synapse

/// Tests for the "typed character renders at body size, then jumps to H1" bug.
///
/// `typingAttributes` decides how AppKit lays out inserted text. It was pinned to
/// the body font for the view's whole lifetime, so every character typed on a
/// heading line was inserted at ~15pt and only grew to the H1 ~31pt when the
/// debounced `applyMarkdownStyling` landed ~80ms later.
///
/// Two things have to hold for the jump to be gone:
///
/// 1. The font must be derived from the line's `#` prefix, NOT sampled from the
///    text storage. On a newly typed heading, storage still holds the body font
///    (the heading font only arrives with the debounced restyle), so a
///    storage-sampling implementation reads body, concludes "no change", and
///    leaves the next character rendering small.
/// 2. The sync must happen BEFORE the insertion. AppKit stamps `typingAttributes`
///    during `insertText:`, while `textViewDidChangeSelection` fires afterwards —
///    so syncing only from the selection callback is always one character late.
final class HeadingTypingAttributesTests: XCTestCase {
    var settings: SettingsManager!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        settings = SettingsManager(configPath: tempDir.appendingPathComponent("settings.yml").path)
        settings.editorFontSize = 15
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        settings = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTextView(string: String, caretAt caret: Int) -> LinkAwareTextView {
        let tv = LinkAwareTextView()
        tv.isEditable = true
        tv.settings = settings
        tv.string = string
        tv.typingAttributes = [
            .font: MarkdownTheme.bodyFont(for: settings),
            .foregroundColor: SynapseTheme.editorForeground,
        ]
        tv.setSelectedRange(NSRange(location: caret, length: 0))
        return tv
    }

    private func typingFontSize(_ tv: LinkAwareTextView) -> CGFloat {
        (tv.typingAttributes[.font] as? NSFont)?.pointSize ?? 0
    }

    // MARK: - The core invariant: typed glyphs land at heading size immediately

    /// Primary regression test for "# Like this" — the reported symptom.
    /// Storage is deliberately left unstyled (as it is mid-typing, before the
    /// debounced restyle) so a storage-sampling implementation cannot pass.
    func test_typingOnFreshHeadingLine_usesH1FontBeforeAnyRestyle() {
        let tv = makeTextView(string: "# ", caretAt: 2)

        tv.insertText("L", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.h1Font(for: settings).pointSize,
            "the first character typed on a fresh '# ' line must already use the H1 font"
        )
    }

    /// The character that *completes* the marker must promote the line, even though
    /// the caret line still reads "#" when insertText: is called.
    func test_typingTheSpaceThatCompletesTheMarker_promotesToH1Immediately() {
        let tv = makeTextView(string: "#", caretAt: 1)

        tv.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.h1Font(for: settings).pointSize,
            "typing the space of '# ' must promote typing attributes to H1 in the same keystroke"
        )
    }

    func test_typingOnHeadingLine_usesCorrectFontForEveryLevel() {
        let expected: [(String, NSFont)] = [
            ("# ", MarkdownTheme.h1Font(for: settings)),
            ("## ", MarkdownTheme.h2Font(for: settings)),
            ("### ", MarkdownTheme.h3Font(for: settings)),
            ("#### ", MarkdownTheme.h4Font(for: settings)),
        ]

        for (marker, font) in expected {
            let tv = makeTextView(string: marker, caretAt: (marker as NSString).length)
            tv.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
            XCTAssertEqual(
                typingFontSize(tv), font.pointSize,
                "typing on \(marker.debugDescription) must use its own heading font"
            )
        }
    }

    /// The heading font must be strictly larger than body — this is the jump itself.
    func test_headingTypingFont_isLargerThanBody() {
        let tv = makeTextView(string: "# ", caretAt: 2)
        tv.insertText("A", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertGreaterThan(
            typingFontSize(tv),
            MarkdownTheme.bodyFont(for: settings).pointSize,
            "a character typed on a heading must not be laid out at body size"
        )
    }

    /// Continuing to type further into the heading keeps the heading font.
    func test_typingMidHeading_keepsHeadingFont() {
        let tv = makeTextView(string: "# Like this", caretAt: 11)
        tv.insertText("!", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.h1Font(for: settings).pointSize,
            "typing at the end of an existing heading must stay at H1"
        )
    }

    // MARK: - Body text must not be dragged up to heading size

    func test_typingOnPlainParagraph_usesBodyFont() {
        let tv = makeTextView(string: "Just a paragraph", caretAt: 16)
        tv.insertText("!", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.bodyFont(for: settings).pointSize,
            "plain paragraph text must keep the body font"
        )
    }

    /// Leaving a heading for a body line must drop back to body size.
    func test_movingFromHeadingToBodyLine_revertsToBodyFont() {
        let tv = makeTextView(string: "# Title\nBody line", caretAt: 3)
        tv.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(typingFontSize(tv), MarkdownTheme.h1Font(for: settings).pointSize)

        // Caret to the body line, then type.
        tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
        tv.insertText("Y", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.bodyFont(for: settings).pointSize,
            "moving off the heading must revert typing attributes to body"
        )
    }

    /// A `#` with no following space is a tag, not a heading.
    func test_typingAfterHashWithoutSpace_staysBodyFont() {
        let tv = makeTextView(string: "#tag", caretAt: 4)
        tv.insertText("s", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.bodyFont(for: settings).pointSize,
            "'#tag' is not a heading and must type at body size"
        )
    }

    func test_typingAfterSevenHashes_staysBodyFont() {
        let tv = makeTextView(string: "####### ", caretAt: 8)
        tv.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(
            typingFontSize(tv),
            MarkdownTheme.bodyFont(for: settings).pointSize,
            "seven hashes exceed the heading range and must type at body size"
        )
    }

    // MARK: - Paragraph style tracks the font

    /// The line box has to grow with the font, or the glyph is laid out large inside
    /// a body-height line and still visibly shifts when the restyle lands.
    func test_headingTypingAttributes_carryMatchingParagraphStyle() {
        let tv = makeTextView(string: "# ", caretAt: 2)
        tv.insertText("A", replacementRange: NSRange(location: NSNotFound, length: 0))

        let style = tv.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let h1 = MarkdownTheme.h1Font(for: settings)
        let expected = MarkdownTheme.paragraphStyle(
            font: h1,
            lineHeightMultiple: MarkdownTheme.lineHeightMultiple(for: settings)
        )

        XCTAssertEqual(
            style?.minimumLineHeight, expected.minimumLineHeight,
            "typing attributes must carry the heading's line height, not the body's"
        )
    }

    /// The text actually inserted must carry the heading font, which is what the
    /// user sees on screen.
    func test_insertedCharacter_carriesHeadingFontInStorage() {
        let tv = makeTextView(string: "# ", caretAt: 2)
        tv.insertText("L", replacementRange: NSRange(location: NSNotFound, length: 0))

        guard let storage = tv.textStorage else { return XCTFail("no storage") }
        let insertedLocation = (tv.string as NSString).range(of: "L").location
        XCTAssertTrue(insertedLocation != NSNotFound, "inserted character must be in the string")

        let font = storage.attribute(.font, at: insertedLocation, effectiveRange: nil) as? NSFont
        XCTAssertEqual(
            font?.pointSize,
            MarkdownTheme.h1Font(for: settings).pointSize,
            "the glyph on screen must be H1-sized the moment it is inserted"
        )
    }
}
