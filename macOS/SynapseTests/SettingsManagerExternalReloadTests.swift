import XCTest
import Combine
@testable import Synapse

final class SettingsManagerExternalReloadTests: XCTestCase {
    private var tempDir: URL!
    private var globalConfigPath: String!
    private var cancellables: Set<AnyCancellable> = []

    private var settingsURL: URL {
        tempDir.appendingPathComponent(".synapse/settings.yml")
    }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: tempDir.appendingPathComponent(".synapse"), withIntermediateDirectories: true)
        globalConfigPath = tempDir.appendingPathComponent("global-settings.yml").path
    }

    override func tearDown() {
        cancellables.removeAll()
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_externalVaultSettingsChange_doesNotReloadPublishedValuesAutomatically() throws {
        let manager = SettingsManager(vaultRoot: tempDir, globalConfigPath: globalConfigPath)
        XCTAssertFalse(manager.dailyNotesEnabled)

        let reloadExpectation = expectation(description: "does not auto-reload after external vault settings change")
        reloadExpectation.isInverted = true
        manager.$dailyNotesEnabled
            .dropFirst()
            .sink { enabled in
                if enabled {
                    reloadExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let yaml = """
        onBootCommand: echo hi
        fileExtensionFilter: "*.md, *.txt"
        templatesDirectory: templates
        dailyNotesEnabled: true
        autoSave: false
        autoPush: false
        """

        try yaml.write(to: settingsURL, atomically: true, encoding: .utf8)

        wait(for: [reloadExpectation], timeout: 1.0)
        XCTAssertFalse(manager.dailyNotesEnabled)
    }

    func test_refreshAllFiles_reloadsExternalVaultSettingsChange() throws {
        let settings = SettingsManager(vaultRoot: tempDir, globalConfigPath: globalConfigPath)
        let appState = AppState(settings: settings)
        appState.rootURL = tempDir
        XCTAssertFalse(appState.settings.dailyNotesEnabled)

        let yaml = """
        onBootCommand: echo hi
        fileExtensionFilter: "*.md, *.txt, *.json"
        templatesDirectory: templates
        dailyNotesEnabled: true
        autoSave: false
        autoPush: false
        """
        try yaml.write(to: settingsURL, atomically: true, encoding: .utf8)

        appState.refreshAllFiles()

        XCTAssertTrue(appState.settings.dailyNotesEnabled)
        XCTAssertEqual(appState.settings.fileExtensionFilter, "*.md, *.txt, *.json")
    }
}
