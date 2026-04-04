import XCTest
import SwiftUI
import AppKit
@testable import Synapse

/// Tests that `SynapseTheme` static colors delegate to `ThemeEnvironment.shared` when set.
/// Without this wiring, theme changes would not reach legacy `SynapseTheme.*` call sites.
@MainActor
final class SynapseThemeEnvironmentDelegationTests: XCTestCase {

    private var tempDir: URL!
    private var configPath: String!
    private var settings: SettingsManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configPath = tempDir.appendingPathComponent("synapse-theme-delegation.json").path
        settings = SettingsManager(configPath: configPath)
    }

    override func tearDown() {
        settings = nil
        try? FileManager.default.removeItem(at: tempDir)
        ThemeEnvironment.shared = nil
        super.tearDown()
    }

    func test_canvas_delegatesToSharedEnvironment() {
        settings.activeThemeName = "Dracula (Dark)"
        let env = ThemeEnvironment()
        env.observe(settings)

        XCTAssertEqual(
            SynapseTheme.canvas,
            env.canvas,
            "SynapseTheme.canvas should follow ThemeEnvironment when shared is set"
        )
    }

    func test_textPrimary_delegatesToSharedEnvironment() {
        settings.activeThemeName = "Synapse (Light)"
        let env = ThemeEnvironment()
        env.observe(settings)

        XCTAssertEqual(SynapseTheme.textPrimary, env.textPrimary)
    }

    func test_editorBackground_delegatesToSharedEnvironment() {
        settings.activeThemeName = "Dracula (Dark)"
        let env = ThemeEnvironment()
        env.observe(settings)

        XCTAssertEqual(SynapseTheme.editorBackground, env.nsEditorBackground)
    }

    func test_withoutSharedEnvironment_usesStaticFallbackCanvas() {
        ThemeEnvironment.shared = nil
        XCTAssertEqual(SynapseTheme.canvas, SynapseTheme._canvas)
    }
}
