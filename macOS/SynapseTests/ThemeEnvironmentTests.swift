import AppKit
import XCTest
@testable import Synapse

/// Tests for ThemeEnvironment: wiring to SettingsManager, shared singleton, and light/dark detection.
final class ThemeEnvironmentTests: XCTestCase {

    private var configPath: String!
    private var settings: SettingsManager!
    private var previousShared: ThemeEnvironment?

    override func setUp() {
        super.setUp()
        previousShared = ThemeEnvironment.shared
        ThemeEnvironment.shared = nil
        configPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("Synapse-theme-test-\(UUID().uuidString).yml")
        settings = SettingsManager(configPath: configPath)
    }

    override func tearDown() {
        ThemeEnvironment.shared = nil
        settings = nil
        if let configPath {
            try? FileManager.default.removeItem(atPath: configPath)
        }
        configPath = nil
        ThemeEnvironment.shared = previousShared
        previousShared = nil
        super.tearDown()
    }

    func test_observe_setsSharedAndInitialTheme() {
        let env = ThemeEnvironment()
        env.observe(settings)

        XCTAssertTrue(env === ThemeEnvironment.shared)
        XCTAssertEqual(env.theme.name, settings.activeTheme.name)
    }

    func test_observe_activeThemeNameChange_updatesPublishedTheme() {
        let env = ThemeEnvironment()
        env.observe(settings)

        XCTAssertEqual(env.theme.name, "Synapse (Dark)")

        settings.activeThemeName = "Synapse (Light)"
        let exp = expectation(description: "theme sink on main")
        DispatchQueue.main.async {
            DispatchQueue.main.async { exp.fulfill() }
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(env.theme.name, "Synapse (Light)")
        XCTAssertTrue(env.isLightTheme)
        XCTAssertEqual(env.nsAppearance.name, NSAppearance.Name.aqua)
    }

    func test_isLightTheme_falseForSynapseDark() {
        let env = ThemeEnvironment()
        env.observe(settings)

        settings.activeThemeName = "Synapse (Dark)"
        let exp = expectation(description: "theme dark")
        DispatchQueue.main.async {
            DispatchQueue.main.async { exp.fulfill() }
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertFalse(env.isLightTheme)
        XCTAssertEqual(env.nsAppearance.name, NSAppearance.Name.darkAqua)
    }
}
