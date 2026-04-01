import XCTest
@testable import Synapse

/// Unit tests for logic extracted from critical UI panes (browser, terminal, tags,
/// all-files search ordering, update banner) that previously had no direct coverage.
final class MiniBrowserURLNormalizerTests: XCTestCase {

    func test_emptyInput_returnsNil() {
        XCTAssertNil(MiniBrowserURLNormalizer.normalizedURL(for: ""))
        XCTAssertNil(MiniBrowserURLNormalizer.normalizedURL(for: "   \n\t"))
    }

    func test_httpsPreserved() {
        let pair = MiniBrowserURLNormalizer.normalizedURL(for: "https://example.com/path")
        XCTAssertEqual(pair?.string, "https://example.com/path")
        XCTAssertEqual(pair?.url.absoluteString, "https://example.com/path")
    }

    func test_httpPreserved() {
        let pair = MiniBrowserURLNormalizer.normalizedURL(for: "http://local.test")
        XCTAssertEqual(pair?.string, "http://local.test")
    }

    func test_hostOnly_getsHttpsScheme() {
        let pair = MiniBrowserURLNormalizer.normalizedURL(for: "example.com/foo")
        XCTAssertEqual(pair?.string, "https://example.com/foo")
        XCTAssertEqual(pair?.url.scheme, "https")
    }

    func test_trimsWhitespace() {
        let pair = MiniBrowserURLNormalizer.normalizedURL(for: "  github.com  ")
        XCTAssertEqual(pair?.string, "https://github.com")
    }
}

final class TerminalBootCommandBuilderTests: XCTestCase {

    func test_cdOnly_whenNoBootCommand() {
        let line = TerminalBootCommandBuilder.shellCommandLine(
            workingDirectory: "/Users/me/vault",
            onBootCommand: nil
        )
        XCTAssertEqual(line, "cd /Users/me/vault")
    }

    func test_cdOnly_whenBootCommandEmpty() {
        let line = TerminalBootCommandBuilder.shellCommandLine(
            workingDirectory: "/tmp",
            onBootCommand: "  "
        )
        XCTAssertEqual(line, "cd /tmp")
    }

    func test_escapesSpacesInPath() {
        let line = TerminalBootCommandBuilder.shellCommandLine(
            workingDirectory: "/Users/me/My Vault",
            onBootCommand: nil
        )
        XCTAssertEqual(line, "cd /Users/me/My\\ Vault")
    }

    func test_appendsCustomBootCommand() {
        let line = TerminalBootCommandBuilder.shellCommandLine(
            workingDirectory: "/proj",
            onBootCommand: "npm install"
        )
        XCTAssertEqual(line, "cd /proj && npm install")
    }
}

final class TagsPaneFilteringTests: XCTestCase {

    func test_emptyFilter_returnsAllSortedByKey() {
        let tags = ["zebra": 1, "alpha": 2]
        let filtered = TagsPaneFiltering.sortedFilteredTags(from: tags, filter: "")
        XCTAssertEqual(filtered.map(\.key), ["alpha", "zebra"])
        XCTAssertEqual(filtered.map(\.value), [2, 1])
    }

    func test_filterIsCaseInsensitive() {
        let tags = ["SwiftUI": 1, "swift": 2]
        let filtered = TagsPaneFiltering.sortedFilteredTags(from: tags, filter: "SWIFT")
        XCTAssertEqual(filtered.count, 2)
    }

    func test_whitespaceOnlyFilter_treatsAsNonEmpty() {
        let tags = ["a": 1]
        let filtered = TagsPaneFiltering.sortedFilteredTags(from: tags, filter: "   ")
        XCTAssertTrue(filtered.isEmpty, "Spaces do not match tag keys")
    }
}

final class AllFilesSearchResultSortingTests: XCTestCase {

    private func result(url: URL, line: Int) -> FileSearchResult {
        FileSearchResult(url: url, snippet: "", lineNumber: line)
    }

    func test_sortsByNewerModificationDateFirst() {
        let older = URL(fileURLWithPath: "/a.md")
        let newer = URL(fileURLWithPath: "/b.md")
        let d1 = Date(timeIntervalSince1970: 100)
        let d2 = Date(timeIntervalSince1970: 200)
        let modDates = [older: d1, newer: d2]
        let input = [result(url: older, line: 1), result(url: newer, line: 1)]
        let sorted = AllFilesSearchResultSorting.sortByModificationDate(input, modDates: modDates)
        XCTAssertEqual(sorted.map(\.url.path), [newer.path, older.path])
    }

    func test_sameFileUsesLineNumberAsTiebreaker() {
        let url = URL(fileURLWithPath: "/note.md")
        let modDates = [url: Date()]
        let input = [result(url: url, line: 5), result(url: url, line: 2)]
        let sorted = AllFilesSearchResultSorting.sortByModificationDate(input, modDates: modDates)
        XCTAssertEqual(sorted.map(\.lineNumber), [2, 5])
    }

    func test_missingModDate_sortsAsDistantPast() {
        let withDate = URL(fileURLWithPath: "/with.md")
        let noDate = URL(fileURLWithPath: "/missing.md")
        let modDates = [withDate: Date(timeIntervalSince1970: 500)]
        let input = [result(url: noDate, line: 1), result(url: withDate, line: 1)]
        let sorted = AllFilesSearchResultSorting.sortByModificationDate(input, modDates: modDates)
        XCTAssertEqual(sorted.map(\.url.path), [withDate.path, noDate.path])
    }
}

final class UpdateBannerCopyTests: XCTestCase {

    func test_icon_restartUsesCheckmark() {
        XCTAssertEqual(
            UpdateBannerCopy.iconName(downloadProgress: nil, restartRequired: true),
            "checkmark.circle.fill"
        )
    }

    func test_title_available() {
        XCTAssertEqual(
            UpdateBannerCopy.titleText(version: "2.0", downloadProgress: nil, restartRequired: false),
            "Update available: v2.0"
        )
    }

    func test_title_downloading_roundsPercent() {
        XCTAssertEqual(
            UpdateBannerCopy.titleText(version: "1.1", downloadProgress: 0.456, restartRequired: false),
            "Downloading v1.1… 45%"
        )
    }

    func test_title_installed() {
        XCTAssertEqual(
            UpdateBannerCopy.titleText(version: "3.0", downloadProgress: nil, restartRequired: true),
            "Synapse v3.0 installed"
        )
    }

    func test_subtitle() {
        XCTAssertEqual(UpdateBannerCopy.subtitleText(restartRequired: false), "Click Install to update automatically")
        XCTAssertEqual(UpdateBannerCopy.subtitleText(restartRequired: true), "Restart to finish updating")
    }
}
