import XCTest
@testable import Synapse

/// Tests for SettingsManager sidebar pane height persistence.
/// leftPaneHeights / rightPaneHeights store the proportional height allocation
/// for each pane in the left and right sidebars, keyed by SidebarPane.rawValue.
/// These settings allow the user's sidebar layout to survive app restarts.
final class SettingsManagerPaneHeightsTests: XCTestCase {

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

    // MARK: - Default values

    func test_initialState_leftPaneHeights_isEmpty() {
        XCTAssertTrue(sut.leftPaneHeights.isEmpty, "Default left pane heights should be an empty dictionary")
    }

    func test_initialState_rightPaneHeights_isEmpty() {
        XCTAssertTrue(sut.rightPaneHeights.isEmpty, "Default right pane heights should be an empty dictionary")
    }

    // MARK: - Setting heights

    func test_leftPaneHeights_canBeSetForSinglePane() {
        sut.leftPaneHeights = ["files": 200]

        XCTAssertEqual(sut.leftPaneHeights["files"], 200)
    }

    func test_leftPaneHeights_canBeSetForMultiplePanes() {
        sut.leftPaneHeights = ["files": 200, "tags": 150, "links": 100]

        XCTAssertEqual(sut.leftPaneHeights["files"], 200)
        XCTAssertEqual(sut.leftPaneHeights["tags"], 150)
        XCTAssertEqual(sut.leftPaneHeights["links"], 100)
    }

    func test_rightPaneHeights_canBeSet() {
        sut.rightPaneHeights = ["terminal": 300]

        XCTAssertEqual(sut.rightPaneHeights["terminal"], 300)
    }

    func test_paneHeight_missingKey_returnsNil() {
        sut.leftPaneHeights = ["files": 200]

        XCTAssertNil(sut.leftPaneHeights["terminal"], "Missing key should return nil, not a default value")
    }

    // MARK: - Persistence

    func test_leftPaneHeights_persistToDisk() {
        sut.leftPaneHeights = ["files": 250, "tags": 180]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertEqual(newManager.leftPaneHeights["files"], 250)
        XCTAssertEqual(newManager.leftPaneHeights["tags"], 180)
    }

    func test_rightPaneHeights_persistToDisk() {
        sut.rightPaneHeights = ["terminal": 400, "graph": 200]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertEqual(newManager.rightPaneHeights["terminal"], 400)
        XCTAssertEqual(newManager.rightPaneHeights["graph"], 200)
    }

    func test_leftAndRightPaneHeights_independentlyPersist() {
        sut.leftPaneHeights = ["files": 300]
        sut.rightPaneHeights = ["terminal": 500]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertEqual(newManager.leftPaneHeights["files"], 300)
        XCTAssertEqual(newManager.rightPaneHeights["terminal"], 500)
        XCTAssertNil(newManager.leftPaneHeights["terminal"])
        XCTAssertNil(newManager.rightPaneHeights["files"])
    }

    func test_updatedPaneHeight_persistsNewValue() {
        sut.leftPaneHeights = ["files": 100]
        sut.leftPaneHeights = ["files": 200]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertEqual(newManager.leftPaneHeights["files"], 200, "Updated height should overwrite the previous value")
    }

    func test_clearedPaneHeights_persistAsEmpty() {
        sut.leftPaneHeights = ["files": 200]
        sut.leftPaneHeights = [:]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertTrue(newManager.leftPaneHeights.isEmpty, "Clearing pane heights should persist as an empty dictionary")
    }

    // MARK: - Missing config uses empty defaults

    func test_missingPaneHeightsInConfig_defaultsToEmpty() {
        let config: [String: Any] = [
            "onBootCommand": "",
            "fileExtensionFilter": "*.md, *.txt",
            "autoSave": false,
            "autoPush": false
        ]
        let data = try! JSONSerialization.data(withJSONObject: config)
        try! data.write(to: URL(fileURLWithPath: configFilePath))

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertTrue(newManager.leftPaneHeights.isEmpty, "Missing leftPaneHeights in config should default to empty")
        XCTAssertTrue(newManager.rightPaneHeights.isEmpty, "Missing rightPaneHeights in config should default to empty")
    }

    // MARK: - Observable changes

    func test_settingLeftPaneHeights_triggersObjectWillChange() {
        var changeCount = 0
        let cancellable = sut.objectWillChange.sink { _ in changeCount += 1 }

        sut.leftPaneHeights = ["files": 300]

        XCTAssertGreaterThanOrEqual(changeCount, 1, "Modifying leftPaneHeights should publish an objectWillChange notification")
        cancellable.cancel()
    }

    func test_settingRightPaneHeights_triggersObjectWillChange() {
        var changeCount = 0
        let cancellable = sut.objectWillChange.sink { _ in changeCount += 1 }

        sut.rightPaneHeights = ["terminal": 250]

        XCTAssertGreaterThanOrEqual(changeCount, 1, "Modifying rightPaneHeights should publish an objectWillChange notification")
        cancellable.cancel()
    }

    // MARK: - Coexistence with other settings

    func test_paneHeights_doNotInterfereWithSidebarPaneOrder() {
        sut.leftPaneHeights = ["files": 200]
        sut.leftSidebarPanes = [.tags, .files]

        let newManager = SettingsManager(configPath: configFilePath)

        XCTAssertEqual(newManager.leftPaneHeights["files"], 200)
        XCTAssertEqual(newManager.leftSidebarPanes, [.tags, .files])
    }
}
