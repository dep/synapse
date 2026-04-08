import XCTest
@testable import Synapse

/// Tests for `CachedFile`, the value type backing the vault content cache.
final class CachedFileTests: XCTestCase {

    func test_cachedFile_holdsWikiLinksAndTags() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = CachedFile(
            content: "hello",
            modificationDate: date,
            wikiLinks: ["alpha", "beta"],
            tags: ["swift"]
        )
        XCTAssertEqual(sut.content, "hello")
        XCTAssertEqual(sut.modificationDate, date)
        XCTAssertEqual(sut.wikiLinks, ["alpha", "beta"])
        XCTAssertEqual(sut.tags, ["swift"])
    }

    func test_cachedFile_preservesNilModificationDate() {
        let sut = CachedFile(content: "", modificationDate: nil, wikiLinks: [], tags: [])
        XCTAssertNil(sut.modificationDate)
        XCTAssertTrue(sut.wikiLinks.isEmpty)
        XCTAssertTrue(sut.tags.isEmpty)
    }
}
