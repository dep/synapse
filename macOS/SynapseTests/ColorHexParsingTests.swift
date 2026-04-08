import XCTest
import AppKit
import SwiftUI
@testable import Synapse

/// Tests hex color parsing used by themes and folder pastels (`Color(hex:)` / `NSColor(hexString:)`).
final class ColorHexParsingTests: XCTestCase {

    // MARK: - NSColor(hexString:)

    func test_nsColor_hexString_sixDigitRGB() {
        let c = NSColor(hexString: "#FF8040")!
        guard let rgb = c.usingColorSpace(.deviceRGB) else {
            return XCTFail("Expected deviceRGB color space")
        }
        XCTAssertEqual(rgb.redComponent, 1.0, accuracy: 0.001)
        XCTAssertEqual(rgb.greenComponent, 0.502, accuracy: 0.02)
        XCTAssertEqual(rgb.blueComponent, 0.251, accuracy: 0.02)
        XCTAssertEqual(rgb.alphaComponent, 1.0, accuracy: 0.001)
    }

    func test_nsColor_hexString_withoutHashPrefix() {
        XCTAssertNotNil(NSColor(hexString: "112233"))
    }

    func test_nsColor_hexString_trimsWhitespace() {
        XCTAssertNotNil(NSColor(hexString: "  #AABBCC  "))
    }

    func test_nsColor_hexString_eightDigitRGBA() {
        let c = NSColor(hexString: "#FF000080")!
        XCTAssertLessThan(c.alphaComponent, 1.0)
    }

    func test_nsColor_hexString_invalidLength_returnsNil() {
        XCTAssertNil(NSColor(hexString: "#FFF"))
        XCTAssertNil(NSColor(hexString: "#FF"))
    }

    func test_nsColor_hexString_nonHex_returnsNil() {
        XCTAssertNil(NSColor(hexString: "#GGHHII"))
    }

    // MARK: - Color(hex:)

    func test_color_hex_init_succeedsForValidSixDigit() {
        XCTAssertNotNil(Color(hex: "#00FF00"))
    }

    func test_color_hex_init_nilForInvalid() {
        XCTAssertNil(Color(hex: "not-a-color"))
    }
}
