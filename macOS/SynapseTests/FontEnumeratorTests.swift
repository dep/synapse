import XCTest
import AppKit
@testable import Synapse

/// Tests for FontEnumerator — the utility that populates the font-family picker
/// in SettingsView.  A regression here would break the font selector, leaving
/// users unable to change their editor font or causing the picker to populate
/// with wrong/empty results.
final class FontEnumeratorTests: XCTestCase {

    // MARK: - allSystemFonts

    func test_allSystemFonts_returnsNonEmptyList() {
        let fonts = FontEnumerator.allSystemFonts()
        XCTAssertFalse(fonts.isEmpty,
                       "allSystemFonts() should return at least one font family on any macOS system")
    }

    func test_allSystemFonts_isSortedAlphabetically() {
        let fonts = FontEnumerator.allSystemFonts()
        guard fonts.count > 1 else { return }

        for i in 0 ..< fonts.count - 1 {
            XCTAssertLessThanOrEqual(
                fonts[i].localizedCaseInsensitiveCompare(fonts[i + 1]),
                ComparisonResult.orderedSame,
                "Fonts should be in ascending alphabetical order; '\(fonts[i])' appears before '\(fonts[i + 1])'"
            )
        }
    }

    func test_allSystemFonts_containsCommonFamilies() {
        let fonts = FontEnumerator.allSystemFonts()
        let common = ["Arial", "Helvetica", "Times New Roman", "Georgia", "Courier New"]
        for name in common {
            XCTAssertTrue(
                fonts.contains(name),
                "'\(name)' is a system font family that should be present in allSystemFonts()"
            )
        }
    }

    func test_allSystemFonts_noDuplicates() {
        let fonts = FontEnumerator.allSystemFonts()
        let unique = Set(fonts)
        XCTAssertEqual(
            unique.count, fonts.count,
            "allSystemFonts() must not contain duplicate font family names"
        )
    }

    // MARK: - monospaceFonts

    func test_monospaceFonts_returnsNonEmptyList() {
        let fonts = FontEnumerator.monospaceFonts()
        XCTAssertFalse(fonts.isEmpty,
                       "monospaceFonts() should return at least one monospace family on macOS")
    }

    func test_monospaceFonts_isSubsetOfAllSystemFonts() {
        let all = Set(FontEnumerator.allSystemFonts())
        let mono = FontEnumerator.monospaceFonts()

        for name in mono {
            XCTAssertTrue(all.contains(name),
                          "'\(name)' from monospaceFonts() must also appear in allSystemFonts()")
        }
    }

    func test_monospaceFonts_containsExpectedMonoFamily() {
        let mono = FontEnumerator.monospaceFonts()
        // Menlo ships with every macOS version and is always monospace.
        XCTAssertTrue(mono.contains("Menlo"),
                      "'Menlo' is a system monospace font and must appear in monospaceFonts()")
    }

    func test_monospaceFonts_eachFontHasMonospaceSymbolicTrait() {
        let mono = FontEnumerator.monospaceFonts()
        for familyName in mono {
            if let font = NSFont(name: familyName, size: 12) ?? NSFont(name: "\(familyName)-Regular", size: 12) {
                let traits = font.fontDescriptor.symbolicTraits
                XCTAssertTrue(traits.contains(.monoSpace),
                              "'\(familyName)' returned by monospaceFonts() must have the monoSpace symbolic trait")
            }
        }
    }

    // MARK: - bodyFonts

    func test_bodyFonts_returnsNonEmptyList() {
        let fonts = FontEnumerator.bodyFonts()
        XCTAssertFalse(fonts.isEmpty,
                       "bodyFonts() should return at least one body font family")
    }

    func test_bodyFonts_isSubsetOfAllSystemFonts() {
        let all = Set(FontEnumerator.allSystemFonts())
        let body = FontEnumerator.bodyFonts()

        for name in body {
            XCTAssertTrue(all.contains(name),
                          "'\(name)' from bodyFonts() must also appear in allSystemFonts()")
        }
    }

    func test_bodyFonts_excludesSymbolFonts() {
        let body = FontEnumerator.bodyFonts()
        let excluded = ["Apple Symbols", "Webdings", "Wingdings", "Zapf Dingbats"]
        for name in excluded {
            XCTAssertFalse(body.contains(name),
                           "'\(name)' is a decorative/symbol font and should be filtered out by bodyFonts()")
        }
    }

    func test_bodyFonts_doesNotExcludeArialOrHelvetica() {
        let body = FontEnumerator.bodyFonts()
        // These are common body text fonts that must NOT be excluded.
        let expected = ["Arial", "Helvetica"]
        for name in expected {
            XCTAssertTrue(body.contains(name),
                          "'\(name)' is a standard body font and must appear in bodyFonts()")
        }
    }

    func test_bodyFonts_countIsLessThanOrEqualToAllSystemFonts() {
        // Body fonts are a subset (some are filtered); count should not exceed total.
        let all = FontEnumerator.allSystemFonts()
        let body = FontEnumerator.bodyFonts()
        XCTAssertLessThanOrEqual(body.count, all.count,
                                 "bodyFonts() cannot return more families than allSystemFonts()")
    }

    // MARK: - displayName

    func test_displayName_emptyString_notMonospace_returnsSystem() {
        XCTAssertEqual(FontEnumerator.displayName(for: ""),
                       "System",
                       "Empty family name (non-monospace) should map to 'System'")
    }

    func test_displayName_emptyString_monospace_returnsSystemMonospace() {
        XCTAssertEqual(FontEnumerator.displayName(for: "", isMonospace: true),
                       "System Monospace",
                       "Empty family name with isMonospace:true should map to 'System Monospace'")
    }

    func test_displayName_nonEmptyString_returnsItVerbatim() {
        XCTAssertEqual(FontEnumerator.displayName(for: "Helvetica"),
                       "Helvetica",
                       "A non-empty family name should be returned unchanged")
    }

    func test_displayName_nonEmptyString_monospaceFlag_returnsItVerbatim() {
        XCTAssertEqual(FontEnumerator.displayName(for: "Menlo", isMonospace: true),
                       "Menlo",
                       "A non-empty family name should be returned unchanged regardless of isMonospace flag")
    }

    func test_displayName_defaultParameter_isNotMonospace() {
        // Calling without isMonospace should behave like isMonospace: false.
        XCTAssertEqual(FontEnumerator.displayName(for: ""),
                       FontEnumerator.displayName(for: "", isMonospace: false))
    }
}
