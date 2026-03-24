import XCTest
import AppKit
@testable import Synapse

/// Tests for the pure state-consumer helpers in EditorView.swift:
///   - consumePendingCursorPosition(from:for:paneIndex:)
///   - consumePendingScrollOffset(from:for:paneIndex:)
///   - consumePendingSearchQuery(from:)
///
/// These functions bridge AppState into the text view; if they silently return
/// nil when they should return a value (or fail to clear state after consuming),
/// the editor loses its saved cursor position or search highlight on every file
/// switch — bugs that are invisible in normal use but regress real-world UX.
final class EditorStateConsumerTests: XCTestCase {

    var appState: AppState!
    var editableView: NSTextView!
    var readOnlyView: NSTextView!

    override func setUp() {
        super.setUp()
        appState = AppState()
        editableView = RawEditor.configuredTextView(isEditable: true, settings: nil)
        readOnlyView = RawEditor.configuredTextView(isEditable: false, settings: nil)
    }

    override func tearDown() {
        appState = nil
        editableView = nil
        readOnlyView = nil
        super.tearDown()
    }

    // MARK: - consumePendingCursorPosition

    func test_consumePendingCursorPosition_editableViewMatchingPane_returnsPosition() {
        appState.pendingCursorPosition = 42
        appState.pendingCursorTargetPaneIndex = nil  // nil means "any pane"

        let result = consumePendingCursorPosition(from: appState, for: editableView, paneIndex: 0)

        XCTAssertEqual(result, 42, "Should return the pending cursor position for an editable view")
    }

    func test_consumePendingCursorPosition_editableViewMatchingPane_clearsState() {
        appState.pendingCursorPosition = 10
        appState.pendingCursorTargetPaneIndex = nil

        _ = consumePendingCursorPosition(from: appState, for: editableView, paneIndex: 0)

        XCTAssertNil(appState.pendingCursorPosition, "Position should be cleared after consumption")
        XCTAssertNil(appState.pendingCursorTargetPaneIndex, "Target pane index should be cleared after consumption")
    }

    func test_consumePendingCursorPosition_readOnlyView_returnsNil() {
        appState.pendingCursorPosition = 99

        let result = consumePendingCursorPosition(from: appState, for: readOnlyView, paneIndex: 0)

        XCTAssertNil(result, "Should not consume cursor position for a read-only text view")
        XCTAssertEqual(appState.pendingCursorPosition, 99, "State should not be cleared when view is read-only")
    }

    func test_consumePendingCursorPosition_wrongPane_returnsNil() {
        appState.pendingCursorPosition = 5
        appState.pendingCursorTargetPaneIndex = 0  // explicitly targeted at pane 0

        let result = consumePendingCursorPosition(from: appState, for: editableView, paneIndex: 1)

        XCTAssertNil(result, "Should not consume position when pane index does not match")
        XCTAssertEqual(appState.pendingCursorPosition, 5, "State should not be cleared for wrong pane")
    }

    func test_consumePendingCursorPosition_correctPane_returnsAndClears() {
        appState.pendingCursorPosition = 7
        appState.pendingCursorTargetPaneIndex = 1

        let result = consumePendingCursorPosition(from: appState, for: editableView, paneIndex: 1)

        XCTAssertEqual(result, 7)
        XCTAssertNil(appState.pendingCursorPosition)
    }

    func test_consumePendingCursorPosition_noPendingPosition_returnsNil() {
        appState.pendingCursorPosition = nil

        let result = consumePendingCursorPosition(from: appState, for: editableView, paneIndex: 0)

        XCTAssertNil(result)
    }

    // MARK: - consumePendingScrollOffset

    func test_consumePendingScrollOffset_editableViewNoTargetPane_returnsOffset() {
        appState.pendingScrollOffsetY = 200.0
        appState.pendingCursorTargetPaneIndex = nil

        let result = consumePendingScrollOffset(from: appState, for: editableView, paneIndex: 0)

        XCTAssertEqual(result, 200.0, accuracy: 0.001, "Should return the pending scroll offset")
    }

    func test_consumePendingScrollOffset_editableView_clearsState() {
        appState.pendingScrollOffsetY = 150.0
        appState.pendingCursorTargetPaneIndex = nil

        _ = consumePendingScrollOffset(from: appState, for: editableView, paneIndex: 0)

        XCTAssertNil(appState.pendingScrollOffsetY, "Scroll offset should be cleared after consumption")
    }

    func test_consumePendingScrollOffset_readOnlyView_returnsNil() {
        appState.pendingScrollOffsetY = 50.0

        let result = consumePendingScrollOffset(from: appState, for: readOnlyView, paneIndex: 0)

        XCTAssertNil(result, "Should not consume scroll offset for a read-only view")
        XCTAssertEqual(appState.pendingScrollOffsetY ?? 0, 50.0, accuracy: 0.001,
                       "State must not be cleared when the view is read-only")
    }

    func test_consumePendingScrollOffset_wrongPane_returnsNil() {
        appState.pendingScrollOffsetY = 80.0
        appState.pendingCursorTargetPaneIndex = 0

        let result = consumePendingScrollOffset(from: appState, for: editableView, paneIndex: 1)

        XCTAssertNil(result, "Should not consume scroll offset when pane index does not match")
        XCTAssertEqual(appState.pendingScrollOffsetY ?? 0, 80.0, accuracy: 0.001)
    }

    func test_consumePendingScrollOffset_correctPane_returnsAndClears() {
        appState.pendingScrollOffsetY = 300.0
        appState.pendingCursorTargetPaneIndex = 1

        let result = consumePendingScrollOffset(from: appState, for: editableView, paneIndex: 1)

        XCTAssertEqual(result, 300.0, accuracy: 0.001)
        XCTAssertNil(appState.pendingScrollOffsetY)
    }

    func test_consumePendingScrollOffset_noPendingOffset_returnsNil() {
        appState.pendingScrollOffsetY = nil

        let result = consumePendingScrollOffset(from: appState, for: editableView, paneIndex: 0)

        XCTAssertNil(result)
    }

    // MARK: - consumePendingSearchQuery (the actual EditorView function)

    func test_consumePendingSearchQuery_returnsValueAndClears() {
        appState.pendingSearchQuery = "wikilink"

        let result = consumePendingSearchQuery(from: appState)

        XCTAssertEqual(result, "wikilink", "Should return the pending search query")
        XCTAssertNil(appState.pendingSearchQuery, "Query should be cleared after consumption")
    }

    func test_consumePendingSearchQuery_whenNil_returnsNil() {
        appState.pendingSearchQuery = nil

        let result = consumePendingSearchQuery(from: appState)

        XCTAssertNil(result)
    }

    func test_consumePendingSearchQuery_calledTwice_secondCallReturnsNil() {
        appState.pendingSearchQuery = "atlas"

        let first = consumePendingSearchQuery(from: appState)
        let second = consumePendingSearchQuery(from: appState)

        XCTAssertEqual(first, "atlas")
        XCTAssertNil(second, "Second consumption should return nil since state was cleared")
    }
}
