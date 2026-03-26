import XCTest
@testable import Synapse

/// Tests for MarkdownCalloutDetector — Obsidian-style callouts inside blockquotes.
final class MarkdownCalloutDetectorTests: XCTestCase {
    private var parser: MarkdownDocumentParser!

    override func setUp() {
        super.setUp()
        parser = MarkdownDocumentParser()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func test_detect_extractsNoteKindTitleAndRanges() {
        let markdown = "> [!NOTE] Important\n"
        let doc = parser.parse(markdown)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .blockquote)

        guard let callout = MarkdownCalloutDetector.detect(in: doc.blocks[0], source: doc.source) else {
            return XCTFail("Expected callout")
        }

        XCTAssertEqual(callout.kind, "note")
        XCTAssertNotNil(callout.titleRange)
        if let titleRange = callout.titleRange {
            XCTAssertEqual((doc.source as NSString).substring(with: titleRange), "Important")
        }
        XCTAssertEqual((doc.source as NSString).substring(with: callout.markerRange), "[!NOTE]")
    }

    func test_detect_supportsFoldMarkerSuffix() {
        let markdown = "> [!TIP]+\n"
        let doc = parser.parse(markdown)
        guard let callout = MarkdownCalloutDetector.detect(in: doc.blocks[0], source: doc.source) else {
            return XCTFail("Expected callout with +/- suffix on marker")
        }
        XCTAssertEqual(callout.kind, "tip")
        XCTAssertEqual((doc.source as NSString).substring(with: callout.markerRange), "[!TIP]+")
    }

    func test_detect_returnsNilForPlainBlockquote() {
        let markdown = "> Just a quote\n"
        let doc = parser.parse(markdown)
        XCTAssertNil(MarkdownCalloutDetector.detect(in: doc.blocks[0], source: doc.source))
    }

    func test_detect_returnsNilWhenMarkerKindWouldBeEmpty() {
        let markdown = "> [!] broken\n"
        let doc = parser.parse(markdown)
        XCTAssertNil(MarkdownCalloutDetector.detect(in: doc.blocks[0], source: doc.source))
    }

    func test_detect_lowercasesKind() {
        let markdown = "> [!WARNING] Be careful\n"
        let doc = parser.parse(markdown)
        guard let callout = MarkdownCalloutDetector.detect(in: doc.blocks[0], source: doc.source) else {
            return XCTFail("Expected callout")
        }
        XCTAssertEqual(callout.kind, "warning")
    }
}
