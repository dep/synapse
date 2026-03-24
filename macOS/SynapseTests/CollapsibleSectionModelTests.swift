import XCTest
@testable import Synapse

/// Tests for `CollapsibleSection` model methods not covered by `CollapsibleSectionsTests`:
///   - `toggle()` — flips the collapsed state in place
///   - `getIdentifier()` — returns the stable, content-based section key
///   - `getVisibleText(from:)` edge cases (content at end, overflow guard)
///
/// These methods are critical to the collapsible-sections feature.  `toggle()` is
/// the primary mutation entrypoint for user interaction; `getIdentifier()` is the
/// persistence key used by `CollapsibleStateManager` to restore collapsed state after
/// edits.  A regression here would either break the expand/collapse button or
/// silently reset all collapse state on every keystroke.
final class CollapsibleSectionModelTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a simple section from the given text where the first line is the
    /// header and everything after the first newline is the content.
    private func section(text: String, collapsed: Bool) -> CollapsibleSection {
        let ns = text as NSString
        let headerEnd = ns.range(of: "\n").location
        let headerRange: NSRange
        let contentRange: NSRange

        if headerEnd == NSNotFound {
            headerRange = NSRange(location: 0, length: ns.length)
            contentRange = NSRange(location: ns.length, length: 0)
        } else {
            headerRange = NSRange(location: 0, length: headerEnd)
            let contentStart = headerEnd + 1
            contentRange = NSRange(location: contentStart, length: ns.length - contentStart)
        }

        return CollapsibleSection(
            headerRange: headerRange,
            contentRange: contentRange,
            isCollapsed: collapsed,
            headerText: ns.substring(with: headerRange)
        )
    }

    // MARK: - toggle()

    func test_toggle_fromExpanded_collapsesSection() {
        var s = section(text: "- 09:00 Standup\n    Daily sync\n", collapsed: false)

        s.toggle()

        XCTAssertTrue(s.isCollapsed, "toggle() should change isCollapsed from false to true")
    }

    func test_toggle_fromCollapsed_expandsSection() {
        var s = section(text: "- 11:00 Review\n    PR review session\n", collapsed: true)

        s.toggle()

        XCTAssertFalse(s.isCollapsed, "toggle() should change isCollapsed from true to false")
    }

    func test_toggle_calledTwice_returnsToOriginalState() {
        var s = section(text: "- 14:00 Meeting\n    Agenda\n", collapsed: false)
        let original = s.isCollapsed

        s.toggle()
        s.toggle()

        XCTAssertEqual(s.isCollapsed, original,
                       "Two consecutive toggle() calls must return to the original collapsed state")
    }

    func test_toggle_doesNotAffectRanges() {
        var s = section(text: "- 09:00 Standup\n    Sync\n", collapsed: false)
        let headerBefore = s.headerRange
        let contentBefore = s.contentRange

        s.toggle()

        XCTAssertEqual(s.headerRange, headerBefore,
                       "toggle() must not mutate headerRange")
        XCTAssertEqual(s.contentRange, contentBefore,
                       "toggle() must not mutate contentRange")
    }

    // MARK: - getIdentifier()

    func test_getIdentifier_returnsHeaderText() {
        let headerText = "- 11:20 Presentation Dry Run"
        let s = CollapsibleSection(
            headerRange: NSRange(location: 0, length: headerText.count),
            contentRange: NSRange(location: headerText.count + 1, length: 5),
            isCollapsed: false,
            headerText: headerText
        )

        XCTAssertEqual(s.getIdentifier(), headerText,
                       "getIdentifier() must return the stored headerText verbatim")
    }

    func test_getIdentifier_isStable_regardlessOfCollapseState() {
        let headerText = "- 09:00 Daily Standup"
        var s = CollapsibleSection(
            headerRange: NSRange(location: 0, length: headerText.count),
            contentRange: NSRange(location: headerText.count + 1, length: 20),
            isCollapsed: false,
            headerText: headerText
        )

        let identifierBefore = s.getIdentifier()
        s.toggle()
        let identifierAfter = s.getIdentifier()

        XCTAssertEqual(identifierBefore, identifierAfter,
                       "getIdentifier() must not change when isCollapsed changes")
    }

    func test_getIdentifier_differentSections_produceDifferentIdentifiers() {
        let s1 = CollapsibleSection(
            headerRange: NSRange(location: 0, length: 5),
            contentRange: NSRange(location: 6, length: 10),
            isCollapsed: false,
            headerText: "- 09:00 Standup"
        )
        let s2 = CollapsibleSection(
            headerRange: NSRange(location: 0, length: 5),
            contentRange: NSRange(location: 6, length: 10),
            isCollapsed: false,
            headerText: "- 14:00 Review"
        )

        XCTAssertNotEqual(s1.getIdentifier(), s2.getIdentifier(),
                          "Sections with different headerText must produce different identifiers")
    }

    // MARK: - getVisibleText(from:) edge cases

    func test_getVisibleText_contentAtEndOfDocument_collapses() {
        let text = "- 16:00 Close\n    End-of-day wrap\n"
        var s = section(text: text, collapsed: false)
        s.isCollapsed = true  // manually set since toggle() would flip it back

        // Re-create with collapsed=true to avoid mutability issues
        let ns = text as NSString
        let headerEnd = ns.range(of: "\n").location
        let collapsed = CollapsibleSection(
            headerRange: NSRange(location: 0, length: headerEnd),
            contentRange: NSRange(location: headerEnd + 1, length: ns.length - headerEnd - 1),
            isCollapsed: true,
            headerText: ns.substring(to: headerEnd)
        )

        let result = collapsed.getVisibleText(from: text)

        // Result should contain only the header and NOT the trailing content.
        let header = ns.substring(with: NSRange(location: 0, length: headerEnd))
        XCTAssertTrue(result.hasPrefix(header),
                      "Collapsed section should start with the header text")
        XCTAssertFalse(result.contains("End-of-day wrap"),
                       "Collapsed section should not contain the content")
    }

    func test_getVisibleText_contentRangeOutOfBounds_returnsFullText() {
        let text = "- Header only"
        let badContentRange = NSRange(location: 100, length: 20)  // beyond string length
        let s = CollapsibleSection(
            headerRange: NSRange(location: 0, length: 13),
            contentRange: badContentRange,
            isCollapsed: true,
            headerText: "- Header only"
        )

        let result = s.getVisibleText(from: text)

        XCTAssertEqual(result, text,
                       "When contentRange is out of bounds, getVisibleText should return the full text unmodified")
    }

    func test_getVisibleText_expanded_returnsFullText() {
        let text = "- 09:00 Morning\n    Notes here\n    More notes\n"
        let s = section(text: text, collapsed: false)

        XCTAssertEqual(s.getVisibleText(from: text), text,
                       "Expanded section should return the full text unchanged")
    }
}
