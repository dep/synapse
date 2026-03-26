import XCTest
import AppKit
import SwiftUI
@testable import Synapse

/// Pins key SynapseTheme colours used across chrome, graphs, and the editor.
/// Silent drift breaks visual consistency and accessibility contrast assumptions.
final class SynapseThemeConstantsTests: XCTestCase {

    func test_accentColor_matchesDesignToken() {
        XCTAssertEqual(SynapseTheme.accent, Color(red: 0.28, green: 0.66, blue: 0.98))
    }

    func test_accentSoftColor_matchesDesignToken() {
        XCTAssertEqual(SynapseTheme.accentSoft, Color(red: 0.20, green: 0.48, blue: 0.89))
    }

    func test_successAndErrorColors_matchDesignTokens() {
        XCTAssertEqual(SynapseTheme.success, Color(red: 0.37, green: 0.83, blue: 0.60))
        XCTAssertEqual(SynapseTheme.error, Color(red: 0.95, green: 0.30, blue: 0.30))
    }

    func test_textHierarchy_usesExpectedWhiteOpacities() {
        XCTAssertEqual(SynapseTheme.textPrimary, Color.white.opacity(0.92))
        XCTAssertEqual(SynapseTheme.textSecondary, Color.white.opacity(0.68))
        XCTAssertEqual(SynapseTheme.textMuted, Color.white.opacity(0.45))
    }

    func test_editorNsColors_useExpectedGrayscaleAndLinkTint() {
        XCTAssertTrue(SynapseTheme.editorBackground.isEqual(to: NSColor(white: 0.07, alpha: 1)))
        XCTAssertTrue(SynapseTheme.editorForeground.isEqual(to: NSColor(white: 0.92, alpha: 1)))
        XCTAssertTrue(
            SynapseTheme.editorLink.isEqual(to: NSColor(calibratedRed: 0.47, green: 0.77, blue: 1.00, alpha: 1))
        )
    }
}
