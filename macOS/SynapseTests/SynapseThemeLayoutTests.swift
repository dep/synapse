import XCTest
import CoreGraphics
import Foundation
@testable import Synapse

/// Regression tests for `SynapseTheme.Layout` — spacing and breakpoints drive chrome sizing across the app.
final class SynapseThemeLayoutTests: XCTestCase {

    private let phi = SynapseTheme.Layout.phi

    func test_phi_isGoldenRatio() {
        XCTAssertEqual(phi, 1.61803398875, accuracy: 1e-9)
    }

    func test_spaceSmall_equalsBaseUnit() {
        XCTAssertEqual(SynapseTheme.Layout.spaceSmall, SynapseTheme.Layout.baseUnit)
    }

    func test_spaceMedium_isPhiTimesBaseUnit() {
        let expected = SynapseTheme.Layout.baseUnit * phi
        XCTAssertEqual(SynapseTheme.Layout.spaceMedium, expected, accuracy: 0.0001)
    }

    func test_spaceLarge_isPhiSquaredTimesBaseUnit() {
        let expected = SynapseTheme.Layout.baseUnit * phi * phi
        XCTAssertEqual(SynapseTheme.Layout.spaceLarge, expected, accuracy: 0.0001)
    }

    func test_spaceExtraLarge_isPhiCubedTimesBaseUnit() {
        let expected = SynapseTheme.Layout.baseUnit * CGFloat(pow(Double(phi), 3))
        XCTAssertEqual(SynapseTheme.Layout.spaceExtraLarge, expected, accuracy: 0.0001)
    }

    func test_sidebarBreakpoints_orderCorrectly() {
        let allExpanded = SynapseTheme.Layout.allSidebarsExpandedWidth
        let twoExpanded = SynapseTheme.Layout.twoSidebarsExpandedWidth
        let oneExpanded = SynapseTheme.Layout.oneSidebarExpandedWidth
        XCTAssertGreaterThan(allExpanded, twoExpanded)
        XCTAssertGreaterThan(twoExpanded, oneExpanded)
    }

    func test_minEditorWidth_usesPhiScaling() {
        let expected = 400 * phi
        XCTAssertEqual(SynapseTheme.Layout.minEditorWidth, expected, accuracy: 0.0001)
    }
}
