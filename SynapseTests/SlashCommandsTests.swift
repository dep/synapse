import XCTest
import AppKit
@testable import Synapse

final class SlashCommandsTests: XCTestCase {
    func test_slashCommandContext_detectsSlashTokenAtStartOfLine() {
        let text = "Title\n/time"

        let context = slashCommandContext(in: text, cursor: (text as NSString).length)

        XCTAssertEqual(context, SlashCommandContext(range: NSRange(location: 6, length: 5), query: "time"))
    }

    func test_slashCommandContext_ignoresSlashMidLine() {
        let text = "Title /time"

        let context = slashCommandContext(in: text, cursor: (text as NSString).length)

        XCTAssertNil(context)
    }

    func test_resolveSlashCommandOutput_formatsDateTimeAndFilenameCommands() {
        let now = Date(timeIntervalSince1970: 1_773_498_840)
        let context = SlashCommandResolverContext(
            now: now,
            currentFileURL: URL(fileURLWithPath: "/tmp/my-note.md"),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(resolveSlashCommandOutput(.time, context: context), "2:34 pm")
        XCTAssertEqual(resolveSlashCommandOutput(.date, context: context), "2026-03-14")
        XCTAssertEqual(resolveSlashCommandOutput(.datetime, context: context), "2026-03-14 2:34 PM")
        XCTAssertEqual(resolveSlashCommandOutput(.todo, context: context), "- [ ] ")
        XCTAssertEqual(resolveSlashCommandOutput(.note, context: context), "> **Note:** ")
        XCTAssertEqual(resolveSlashCommandOutput(.filename, context: context), "my-note")
    }

    func test_expandSlashCommandIfNeeded_expandsExactCommandInPlace() {
        let textView = LinkAwareTextView()
        textView.currentFileURL = URL(fileURLWithPath: "/tmp/my-note.md")
        textView.slashCommandNowProvider = { Date(timeIntervalSince1970: 1_773_498_840) }
        textView.slashCommandTimeZone = TimeZone(secondsFromGMT: 0)!
        textView.string = "/time"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.expandSlashCommandIfNeeded()

        XCTAssertEqual(textView.string, "2:34 pm")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
    }

    func test_expandSlashCommandIfNeeded_doesNotExpandPartialCommand() {
        let textView = LinkAwareTextView()
        textView.string = "/ti"
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        textView.expandSlashCommandIfNeeded()

        XCTAssertEqual(textView.string, "/ti")  // unchanged
    }

    func test_expandSlashCommandIfNeeded_doesNotExpandSlashCommandMidLine() {
        let textView = LinkAwareTextView()
        textView.string = "some text /time"
        textView.setSelectedRange(NSRange(location: 15, length: 0))

        textView.expandSlashCommandIfNeeded()

        XCTAssertEqual(textView.string, "some text /time")  // unchanged
    }

    func test_expandSlashCommandIfNeeded_expandsTodoCommand() {
        let textView = LinkAwareTextView()
        textView.slashCommandNowProvider = { Date(timeIntervalSince1970: 1_773_498_840) }
        textView.string = "/todo"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.expandSlashCommandIfNeeded()

        XCTAssertEqual(textView.string, "- [ ] ")
    }

    func test_expandSlashCommandIfNeeded_expandsOnSecondLine() {
        let textView = LinkAwareTextView()
        textView.slashCommandNowProvider = { Date(timeIntervalSince1970: 1_773_498_840) }
        textView.slashCommandTimeZone = TimeZone(secondsFromGMT: 0)!
        textView.string = "First line\n/date"
        let cursor = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        textView.expandSlashCommandIfNeeded()

        XCTAssertEqual(textView.string, "First line\n2026-03-14")
    }
}
