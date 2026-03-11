import XCTest
@testable import Noted

/// Tests for tab bar functionality: tracking multiple open files as tabs
final class AppStateTabsTests: XCTestCase {
    var sut: AppState!
    var tempDir: URL!
    var fileA: URL!
    var fileB: URL!
    var fileC: URL!
    
    override func setUp() {
        super.setUp()
        sut = AppState()
        
        // Create temp directory with test files
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        fileA = tempDir.appendingPathComponent("NoteA.md")
        fileB = tempDir.appendingPathComponent("NoteB.md")
        fileC = tempDir.appendingPathComponent("NoteC.md")
        
        // Create test files
        try! "Content A".write(to: fileA, atomically: true, encoding: .utf8)
        try! "Content B".write(to: fileB, atomically: true, encoding: .utf8)
        try! "Content C".write(to: fileC, atomically: true, encoding: .utf8)
        
        sut.rootURL = tempDir
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDir)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Tab State
    
    func test_initialState_noTabs() {
        XCTAssertTrue(sut.tabs.isEmpty, "Should start with no tabs open")
        XCTAssertNil(sut.activeTabIndex, "Should have no active tab initially")
    }
    
    func test_openFile_addsToTabs() {
        sut.openFile(fileA)
        
        XCTAssertEqual(sut.tabs.count, 1, "Should have one tab after opening a file")
        XCTAssertEqual(sut.tabs[0], fileA, "Tab should contain the opened file")
        XCTAssertEqual(sut.activeTabIndex, 0, "Active tab should be index 0")
    }
    
    func test_openFile_secondFile_replacesCurrentTab() {
        sut.openFile(fileA)
        sut.openFile(fileB)
        
        XCTAssertEqual(sut.tabs.count, 1, "Should still have one tab (replaced)")
        XCTAssertEqual(sut.tabs[0], fileB, "Tab should contain the new file")
        XCTAssertEqual(sut.activeTabIndex, 0, "Active tab should still be index 0")
    }
    
    // MARK: - New Tab
    
    func test_openFileInNewTab_addsSecondTab() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        
        XCTAssertEqual(sut.tabs.count, 2, "Should have two tabs")
        XCTAssertEqual(sut.tabs[0], fileA, "First tab should be fileA")
        XCTAssertEqual(sut.tabs[1], fileB, "Second tab should be fileB")
        XCTAssertEqual(sut.activeTabIndex, 1, "Active tab should be the new tab (index 1)")
    }
    
    func test_openFileInNewTab_threeTabs() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        sut.openFileInNewTab(fileC)
        
        XCTAssertEqual(sut.tabs.count, 3, "Should have three tabs")
        XCTAssertEqual(sut.activeTabIndex, 2, "Active tab should be index 2")
    }
    
    func test_openFileInNewTab_duplicateFile_makesExistingTabActive() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        sut.openFileInNewTab(fileA) // Try to open A again in new tab
        
        XCTAssertEqual(sut.tabs.count, 2, "Should still have only two tabs (no duplicates)")
        XCTAssertEqual(sut.tabs[0], fileA, "First tab should be fileA")
        XCTAssertEqual(sut.tabs[1], fileB, "Second tab should be fileB")
        XCTAssertEqual(sut.activeTabIndex, 0, "Active tab should switch to existing fileA tab (index 0)")
    }
    
    // MARK: - Closing Tabs
    
    func test_closeTab_removesTab() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        
        sut.closeTab(at: 0)
        
        XCTAssertEqual(sut.tabs.count, 1, "Should have one tab after closing")
        XCTAssertEqual(sut.tabs[0], fileB, "Remaining tab should be fileB")
        XCTAssertEqual(sut.activeTabIndex, 0, "Active tab should adjust to remaining tab")
    }
    
    func test_closeActiveTab_focusesLeftTab() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        sut.openFileInNewTab(fileC) // Active is now index 2
        
        sut.closeTab(at: 2) // Close fileC
        
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(sut.activeTabIndex, 1, "Should focus left tab (fileB at index 1)")
        XCTAssertEqual(sut.selectedFile, fileB)
    }
    
    func test_closeTab_whenLeftOfActive_focusesSameIndex() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        sut.openFileInNewTab(fileC) // Active is now index 2
        
        sut.closeTab(at: 0) // Close fileA (left of active)
        
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(sut.activeTabIndex, 1, "Active should adjust from 2 to 1")
        XCTAssertEqual(sut.tabs[1], fileC)
    }
    
    func test_closeLastTab_clearsActiveTab() {
        sut.openFile(fileA)
        
        sut.closeTab(at: 0)
        
        XCTAssertTrue(sut.tabs.isEmpty, "Should have no tabs")
        XCTAssertNil(sut.activeTabIndex, "Should have no active tab")
    }
    
    // MARK: - Switching Tabs
    
    func test_switchTab_changesActiveTab() {
        sut.openFile(fileA)
        sut.openFileInNewTab(fileB)
        
        sut.switchTab(to: 0)
        
        XCTAssertEqual(sut.activeTabIndex, 0, "Should switch to tab 0")
        XCTAssertEqual(sut.selectedFile, fileA)
    }
    
    func test_switchTab_invalidIndex_doesNothing() {
        sut.openFile(fileA)
        
        sut.switchTab(to: 5) // Invalid index
        
        XCTAssertEqual(sut.activeTabIndex, 0, "Should remain at tab 0")
        XCTAssertEqual(sut.selectedFile, fileA)
    }
    
    func test_switchTab_noTabs_doesNothing() {
        sut.switchTab(to: 0) // No tabs open
        
        XCTAssertNil(sut.activeTabIndex)
        XCTAssertNil(sut.selectedFile)
    }
}
