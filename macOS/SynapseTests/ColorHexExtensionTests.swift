import XCTest
import AppKit
import SwiftUI
@testable import Synapse

/// Tests for `NSColor(hexString:)` and `Color(hex:)` — folder pastel colors and theme import rely on these.
final class ColorHexExtensionTests: XCTestCase {

    // MARK: - NSColor(hexString:)

    func test_nsColor_hexString_sixDigitWithHash() {
        let c = NSColor(hexString: "#FF8040")
        XCTAssertNotNil(c)
        guard let srgb = c?.usingColorSpace(.sRGB) else {
            XCTFail("Expected sRGB color")
            return
        }
        XCTAssertEqual(srgb.redComponent, 1.0, accuracy: 0.02)
        XCTAssertEqual(srgb.greenComponent, 0.5, accuracy: 0.02)
        XCTAssertEqual(srgb.blueComponent, 0.25, accuracy: 0.02)
        XCTAssertEqual(srgb.alphaComponent, 1.0, accuracy: 0.001)
    }

    func test_nsColor_hexString_sixDigitWithoutHash() {
        let c = NSColor(hexString: "112233")
        XCTAssertNotNil(c)
        guard let srgb = c?.usingColorSpace(.sRGB) else {
            XCTFail("Expected sRGB color")
            return
        }
        XCTAssertEqual(srgb.redComponent, 17.0 / 255.0, accuracy: 0.02)
        XCTAssertEqual(srgb.greenComponent, 34.0 / 255.0, accuracy: 0.02)
        XCTAssertEqual(srgb.blueComponent, 51.0 / 255.0, accuracy: 0.02)
    }

    func test_nsColor_hexString_eightDigitIncludesAlpha() {
        let c = NSColor(hexString: "#FF000080")
        XCTAssertNotNil(c)
        XCTAssertEqual(c?.alphaComponent, 128.0 / 255.0, accuracy: 0.02)
    }

    func test_nsColor_hexString_trimsWhitespace() {
        XCTAssertNotNil(NSColor(hexString: "  #ABCDEF  "))
    }

    func test_nsColor_hexString_invalidLength_returnsNil() {
        XCTAssertNil(NSColor(hexString: "#FFF"))
        XCTAssertNil(NSColor(hexString: "#GGGGGG"))
    }

    // MARK: - Color(hex:)

    func test_color_hex_folderPaletteLiterals_allParse() {
        let literals = [
            "#F4ACAC", "#F4C4A4", "#F4DFA4", "#B4E4B4", "#B4F4D4", "#A4D4E4",
            "#A4C4F4", "#C4B4F4", "#E4B4F4", "#F4B4D4", "#E4D4B4"
        ]
        for hex in literals {
            XCTAssertNotNil(Color(hex: hex), "Folder palette hex must parse: \(hex)")
        }
    }

    func test_color_hex_invalid_returnsNil() {
        XCTAssertNil(Color(hex: "nope"))
    }
}
