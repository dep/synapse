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

    func test_insertNewline_expandsExactSlashCommandAndSwallowsNewline() {
        let textView = LinkAwareTextView()
        textView.currentFileURL = URL(fileURLWithPath: "/tmp/my-note.md")
        textView.slashCommandNowProvider = { Date(timeIntervalSince1970: 1_773_498_840) }
        textView.slashCommandTimeZone = TimeZone(secondsFromGMT: 0)!
        textView.string = "/time"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.insertNewline(nil)

        XCTAssertEqual(textView.string, "2:34 pm")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
    }

    func test_insertNewline_doesNotExpandPartialCommand() {
        let textView = LinkAwareTextView()
        textView.string = "/ti"
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        textView.insertNewline(nil)

        // "/ti" is not a valid command, so a regular newline is inserted
        XCTAssertEqual(textView.string, "/ti\n")
    }

    func test_insertNewline_doesNotExpandSlashCommandMidLine() {
        let textView = LinkAwareTextView()
        textView.string = "some text /time"
        textView.setSelectedRange(NSRange(location: 15, length: 0))

        textView.insertNewline(nil)

        // mid-line slash is not a command
        XCTAssertEqual(textView.string, "some text /time\n")
    }

    func test_insertNewline_expandsTodo() {
        let textView = LinkAwareTextView()
        textView.slashCommandNowProvider = { Date(timeIntervalSince1970: 1_773_498_840) }
        textView.string = "/todo"
        textView.setSelectedRange(NSRange(location: 5, length: 0))

        textView.insertNewline(nil)

        XCTAssertEqual(textView.string, "- [ ] ")
    }
}
