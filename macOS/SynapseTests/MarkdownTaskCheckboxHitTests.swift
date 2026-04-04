import XCTest
@testable import Synapse

/// Tests for `MarkdownTaskCheckboxHit.replacement` — toggles the marker text used when checking/unchecking tasks.
final class MarkdownTaskCheckboxHitTests: XCTestCase {

    func test_replacement_uncheckedTask_requestsCheck() {
        let hit = MarkdownTaskCheckboxHit(
            itemRange: NSRange(location: 0, length: 10),
            markerRange: NSRange(location: 2, length: 3),
            isChecked: false
        )
        XCTAssertEqual(hit.replacement, "[x]")
    }

    func test_replacement_checkedTask_requestsUncheck() {
        let hit = MarkdownTaskCheckboxHit(
            itemRange: NSRange(location: 0, length: 10),
            markerRange: NSRange(location: 2, length: 3),
            isChecked: true
        )
        XCTAssertEqual(hit.replacement, "[ ]")
    }

    func test_equatable_sameFields() {
        let a = MarkdownTaskCheckboxHit(itemRange: NSRange(location: 0, length: 5), markerRange: NSRange(location: 2, length: 3), isChecked: false)
        let b = MarkdownTaskCheckboxHit(itemRange: NSRange(location: 0, length: 5), markerRange: NSRange(location: 2, length: 3), isChecked: false)
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentCheckedState() {
        let a = MarkdownTaskCheckboxHit(itemRange: NSRange(location: 0, length: 5), markerRange: NSRange(location: 2, length: 3), isChecked: false)
        let b = MarkdownTaskCheckboxHit(itemRange: NSRange(location: 0, length: 5), markerRange: NSRange(location: 2, length: 3), isChecked: true)
        XCTAssertNotEqual(a, b)
    }
}
