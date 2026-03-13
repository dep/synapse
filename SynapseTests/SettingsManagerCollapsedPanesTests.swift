import XCTest
@testable import Synapse

/// Tests for SettingsManager: collapsedPanes and pane-height persistence.
final class SettingsManagerCollapsedPanesTests: XCTestCase {

    var sut: SettingsManager!
    var tempDir: URL!
    var configFilePath: String!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configFilePath = tempDir.appendingPathComponent("settings.json").path
        sut = SettingsManager(configPath: configFilePath)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sut = nil
        super.tearDown()
    }

    // MARK: - collapsedPanes defaults

    func test_collapsedPanes_defaultsToEmpty() {
        XCTAssertTrue(sut.collapsedPanes.isEmpty, "collapsedPanes should default to an empty set")
    }

    // MARK: - collapsedPanes mutations

    func test_collapsedPanes_insertPersists() {
        sut.collapsedPanes.insert(SidebarPane.files.rawValue)
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertTrue(reloaded.collapsedPanes.contains(SidebarPane.files.rawValue))
    }

    func test_collapsedPanes_removePerissts() {
        sut.collapsedPanes.insert(SidebarPane.tags.rawValue)
        sut.collapsedPanes.insert(SidebarPane.links.rawValue)
        sut.collapsedPanes.remove(SidebarPane.tags.rawValue)
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertFalse(reloaded.collapsedPanes.contains(SidebarPane.tags.rawValue))
        XCTAssertTrue(reloaded.collapsedPanes.contains(SidebarPane.links.rawValue))
    }

    func test_collapsedPanes_multipleValuesPersist() {
        sut.collapsedPanes = [SidebarPane.files.rawValue, SidebarPane.terminal.rawValue]
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertEqual(reloaded.collapsedPanes, [SidebarPane.files.rawValue, SidebarPane.terminal.rawValue])
    }

    func test_collapsedPanes_clearingPersists() {
        sut.collapsedPanes = [SidebarPane.files.rawValue]
        sut.collapsedPanes = []
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertTrue(reloaded.collapsedPanes.isEmpty)
    }

    // MARK: - collapsedPanes JSON fallback

    func test_collapsedPanes_missingKeyInJSON_defaultsToEmpty() {
        let config: [String: Any] = [
            "onBootCommand": "",
            "fileExtensionFilter": "*.md, *.txt",
            "autoSave": false,
            "autoPush": false
        ]
        let data = try! JSONSerialization.data(withJSONObject: config)
        try! data.write(to: URL(fileURLWithPath: configFilePath))

        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertTrue(reloaded.collapsedPanes.isEmpty, "Missing collapsedPanes key should default to empty set")
    }

    // MARK: - leftPaneHeights defaults

    func test_leftPaneHeights_defaultsToEmpty() {
        XCTAssertTrue(sut.leftPaneHeights.isEmpty, "leftPaneHeights should default to [:]")
    }

    func test_rightPaneHeights_defaultsToEmpty() {
        XCTAssertTrue(sut.rightPaneHeights.isEmpty, "rightPaneHeights should default to [:]")
    }

    // MARK: - leftPaneHeights persistence

    func test_leftPaneHeights_setValuePersists() {
        sut.leftPaneHeights[SidebarPane.files.rawValue] = 200
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertEqual(reloaded.leftPaneHeights[SidebarPane.files.rawValue], 200)
    }

    func test_leftPaneHeights_multipleValuesPersist() {
        sut.leftPaneHeights[SidebarPane.files.rawValue] = 150
        sut.leftPaneHeights[SidebarPane.tags.rawValue] = 300
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertEqual(reloaded.leftPaneHeights[SidebarPane.files.rawValue], 150)
        XCTAssertEqual(reloaded.leftPaneHeights[SidebarPane.tags.rawValue], 300)
    }

    func test_leftPaneHeights_updateValuePersists() {
        sut.leftPaneHeights[SidebarPane.files.rawValue] = 100
        sut.leftPaneHeights[SidebarPane.files.rawValue] = 250
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertEqual(reloaded.leftPaneHeights[SidebarPane.files.rawValue], 250)
    }

    // MARK: - rightPaneHeights persistence

    func test_rightPaneHeights_setValuePersists() {
        sut.rightPaneHeights[SidebarPane.terminal.rawValue] = 400
        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertEqual(reloaded.rightPaneHeights[SidebarPane.terminal.rawValue], 400)
    }

    // MARK: - JSON fallback for pane heights

    func test_leftPaneHeights_missingKeyInJSON_defaultsToEmpty() {
        let config: [String: Any] = [
            "onBootCommand": "",
            "fileExtensionFilter": "*.md, *.txt",
            "autoSave": false,
            "autoPush": false
        ]
        let data = try! JSONSerialization.data(withJSONObject: config)
        try! data.write(to: URL(fileURLWithPath: configFilePath))

        let reloaded = SettingsManager(configPath: configFilePath)
        XCTAssertTrue(reloaded.leftPaneHeights.isEmpty, "Missing leftPaneHeights should default to [:]")
        XCTAssertTrue(reloaded.rightPaneHeights.isEmpty, "Missing rightPaneHeights should default to [:]")
    }

    // MARK: - Change notifications

    func test_collapsedPanes_triggersSaveNotification() {
        var notifyCount = 0
        let cancellable = sut.objectWillChange.sink { _ in notifyCount += 1 }
        sut.collapsedPanes.insert("files")
        XCTAssertGreaterThanOrEqual(notifyCount, 1)
        cancellable.cancel()
    }

    func test_leftPaneHeights_triggersSaveNotification() {
        var notifyCount = 0
        let cancellable = sut.objectWillChange.sink { _ in notifyCount += 1 }
        sut.leftPaneHeights["files"] = 100
        XCTAssertGreaterThanOrEqual(notifyCount, 1)
        cancellable.cancel()
    }
}
