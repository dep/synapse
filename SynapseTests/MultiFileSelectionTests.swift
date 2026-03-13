import XCTest
@testable import Synapse

/// Tests for multi-file selection and operations in the sidebar
/// Addresses GitHub issue #47: feat: multi-file operations in the sidebar
final class MultiFileSelectionTests: XCTestCase {
    
    var sut: AppState!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        sut = AppState()
        sut.rootURL = tempDirectory
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        sut = nil
        super.tearDown()
    }
    
    func test_selectedFiles_initiallyEmpty() {
        // Then: No files should be selected initially
        XCTAssertTrue(sut.selectedFiles.isEmpty)
    }
    
    func test_toggleFileSelection_addsAndRemovesFiles() {
        // Given: Create test files
        let file1 = createFile(at: "notes/file1.md")
        let file2 = createFile(at: "notes/file2.md")
        sut.refreshAllFiles()
        
        // When: Toggle selection of first file
        sut.toggleFileSelection(file1)
        
        // Then: File1 should be selected
        XCTAssertTrue(sut.selectedFiles.contains(file1))
        XCTAssertEqual(sut.selectedFiles.count, 1)
        
        // When: Toggle selection of second file
        sut.toggleFileSelection(file2)
        
        // Then: Both files should be selected
        XCTAssertTrue(sut.selectedFiles.contains(file1))
        XCTAssertTrue(sut.selectedFiles.contains(file2))
        XCTAssertEqual(sut.selectedFiles.count, 2)
        
        // When: Toggle selection of first file again
        sut.toggleFileSelection(file1)
        
        // Then: Only file2 should be selected
        XCTAssertFalse(sut.selectedFiles.contains(file1))
        XCTAssertTrue(sut.selectedFiles.contains(file2))
        XCTAssertEqual(sut.selectedFiles.count, 1)
    }
    
    func test_selectFilesRange_selectsAllFilesInBetween() {
        // Given: Create test files in order
        let file1 = createFile(at: "notes/aaa.md")
        let file2 = createFile(at: "notes/bbb.md")
        let file3 = createFile(at: "notes/ccc.md")
        let file4 = createFile(at: "notes/ddd.md")
        sut.refreshAllFiles()
        
        // When: Select range from file1 to file4
        sut.selectFilesRange(from: file1, to: file4)
        
        // Then: All files should be selected
        XCTAssertTrue(sut.selectedFiles.contains(file1))
        XCTAssertTrue(sut.selectedFiles.contains(file2))
        XCTAssertTrue(sut.selectedFiles.contains(file3))
        XCTAssertTrue(sut.selectedFiles.contains(file4))
        XCTAssertEqual(sut.selectedFiles.count, 4)
    }
    
    func test_clearFileSelection_removesAllSelections() {
        // Given: Multiple files selected
        let file1 = createFile(at: "notes/file1.md")
        let file2 = createFile(at: "notes/file2.md")
        sut.refreshAllFiles()
        sut.toggleFileSelection(file1)
        sut.toggleFileSelection(file2)
        XCTAssertEqual(sut.selectedFiles.count, 2)
        
        // When: Clear selection
        sut.clearFileSelection()
        
        // Then: No files should be selected
        XCTAssertTrue(sut.selectedFiles.isEmpty)
    }
    
    func test_isFileSelected_returnsCorrectState() {
        // Given: Create test file
        let file = createFile(at: "notes/file.md")
        sut.refreshAllFiles()
        
        // Then: File should not be selected initially
        XCTAssertFalse(sut.isFileSelected(file))
        
        // When: Select the file
        sut.toggleFileSelection(file)
        
        // Then: File should be selected
        XCTAssertTrue(sut.isFileSelected(file))
    }
    
    func test_deleteSelectedFiles_deletesMultipleFiles() throws {
        // Given: Multiple files selected
        let file1 = createFile(at: "notes/file1.md")
        let file2 = createFile(at: "notes/file2.md")
        let file3 = createFile(at: "notes/file3.md")
        sut.refreshAllFiles()
        sut.toggleFileSelection(file1)
        sut.toggleFileSelection(file2)
        XCTAssertEqual(sut.selectedFiles.count, 2)
        
        // When: Delete selected files
        sut.deleteSelectedFiles()
        
        // Then: Selected files should be deleted, unselected should remain
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file3.path))
        
        // And: Selection should be cleared
        XCTAssertTrue(sut.selectedFiles.isEmpty)
    }
    
    func test_selectedFilesCount_returnsCorrectCount() {
        // Given: Multiple files selected
        let file1 = createFile(at: "notes/file1.md")
        let file2 = createFile(at: "notes/file2.md")
        sut.refreshAllFiles()
        
        // Then: Count should be 0 initially
        XCTAssertEqual(sut.selectedFilesCount, 0)
        
        // When: Select files
        sut.toggleFileSelection(file1)
        XCTAssertEqual(sut.selectedFilesCount, 1)
        
        sut.toggleFileSelection(file2)
        XCTAssertEqual(sut.selectedFilesCount, 2)
    }
    
    // MARK: - Helpers
    
    @discardableResult
    private func createFile(at path: String) -> URL {
        let url = tempDirectory.appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "Content".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
