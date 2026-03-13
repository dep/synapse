import Foundation

/// Represents a pinned item (note or folder) for quick access
struct PinnedItem: Codable, Equatable, Identifiable {
    let id: UUID
    let url: URL
    let name: String
    let isFolder: Bool
    let vaultPath: String
    
    init(url: URL, isFolder: Bool, vaultURL: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.isFolder = isFolder
        self.vaultPath = vaultURL.path
    }
    
    /// Check if the item still exists on disk
    var exists: Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && (isDirectory.boolValue == isFolder)
    }
}
