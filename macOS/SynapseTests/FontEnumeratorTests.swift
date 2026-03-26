import XCTest
import AppKit
@testable import Synapse

/// Tests for FontEnumerator — system font listing and filtering used by the font picker.
/// Wrong sorting or filtering breaks monospace/body font selection in settings.
final class FontEnumeratorTests: XCTestCase {

    func test_allSystemFonts_isSortedCaseInsensitive() {
        let fonts = FontEnumerator.allSystemFonts()
        XCTAssertFalse(fonts.isEmpty, "Expected at least one system font family")

        for i in 0..<(fonts.count - 1) {
            let cmp = fonts[i].localizedCaseInsensitiveCompare(fonts[i + 1])
            XCTAssertLessThanOrEqual(cmp.rawValue, 0,
                                     "Fonts should be sorted A–Z ignoring case: \(fonts[i]) before \(fonts[i + 1])")
        }
    }

    func test_monospaceFonts_isSubsetOfAllSystemFonts() {
        let all = Set(FontEnumerator.allSystemFonts())
        let mono = FontEnumerator.monospaceFonts()
        XCTAssertFalse(mono.isEmpty, "Expected at least one monospace family on macOS")
        for family in mono {
            XCTAssertTrue(all.contains(family), "Monospace family should appear in allSystemFonts: \(family)")
        }
    }

    func test_bodyFonts_excludesKnownSymbolLikePrefixes() {
        let body = FontEnumerator.bodyFonts()
        let excludedPrefixes = [
            "Apple Symbols",
            "Webdings",
            "Wingdings",
            "Zapf Dingbats",
            "Symbols",
            "Emoji"
        ]
        for family in body {
            for prefix in excludedPrefixes {
                XCTAssertFalse(
                    family.hasPrefix(prefix),
                    "bodyFonts should exclude families starting with \(prefix): found \(family)"
                )
            }
        }
    }

    func test_displayName_emptyUsesSystemLabels() {
        XCTAssertEqual(FontEnumerator.displayName(for: "", isMonospace: false), "System")
        XCTAssertEqual(FontEnumerator.displayName(for: "", isMonospace: true), "System Monospace")
    }

    func test_displayName_nonEmptyReturnsFamilyName() {
        XCTAssertEqual(FontEnumerator.displayName(for: "Helvetica"), "Helvetica")
        XCTAssertEqual(FontEnumerator.displayName(for: "Menlo", isMonospace: true), "Menlo")
    }
}
