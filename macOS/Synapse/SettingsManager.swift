import SwiftUI
import Combine
import Yams

enum SidebarPane: String, Codable, CaseIterable, Identifiable {
    case files = "files"
    case tags = "tags"
    case links = "links"
    case terminal = "terminal"
    case graph = "graph"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: return "Files"
        case .tags: return "Tags"
        case .links: return "Related"
        case .terminal: return "Terminal"
        case .graph: return "Graph"
        }
    }
}

/// Position of a sidebar container (left or right side of the window)
enum SidebarPosition: String, Codable, CaseIterable {
    case left = "left"
    case right = "right"
}

/// A sidebar container that can hold multiple panes and be positioned on left or right
struct Sidebar: Identifiable, Codable, Equatable {
    let id: UUID
    var position: SidebarPosition
    var panes: [SidebarPane]
    
    init(id: UUID, position: SidebarPosition, panes: [SidebarPane] = []) {
        self.id = id
        self.position = position
        self.panes = panes
    }
}

/// The app always has exactly 3 sidebars with stable IDs so collapse state
/// persists reliably across restarts without needing to store the sidebar list.
enum FixedSidebar {
    /// Left sidebar: Files + Related panes
    static let leftID   = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    /// Right sidebar #1: Terminal + Tags panes
    static let right1ID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    /// Right sidebar #2: empty, collapsed by default
    static let right2ID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static let all: [Sidebar] = [
        Sidebar(id: leftID,   position: .left,  panes: [.files, .links]),
        Sidebar(id: right1ID, position: .right, panes: [.terminal, .tags]),
        Sidebar(id: right2ID, position: .right, panes: []),
    ]
}

/// Manages application settings with persistence to a local JSON config file
class SettingsManager: ObservableObject {
    private static let vaultSettingsFilename = "settings.yml"
    private static let globalSettingsFilename = "settings.yml"

    @Published var onBootCommand: String {
        didSet { save() }
    }
    @Published var fileExtensionFilter: String {
        didSet { save() }
    }
    @Published var hiddenFileFolderFilter: String {
        didSet { save() }
    }
    @Published var templatesDirectory: String {
        didSet { save() }
    }
    @Published var dailyNotesEnabled: Bool {
        didSet { save() }
    }
    @Published var dailyNotesFolder: String {
        didSet { save() }
    }
    @Published var dailyNotesTemplate: String {
        didSet { save() }
    }
    @Published var dailyNotesOpenOnStartup: Bool {
        didSet { save() }
    }
    @Published var autoSave: Bool {
        didSet { save() }
    }
    @Published var autoPush: Bool {
        didSet { save() }
    }
    /// The 3 fixed sidebars. Structure (IDs/positions) never changes; pane assignments are mutable.
    @Published var sidebars: [Sidebar] {
        didSet { save() }
    }

    /// Pane heights keyed by SidebarPane rawValue (shared across all sidebars)
    @Published var sidebarPaneHeights: [String: CGFloat] {
        didSet { save() }
    }
    /// Set of pane rawValues that are currently collapsed
    @Published var collapsedPanes: Set<String> {
        didSet { save() }
    }
    /// Set of sidebar UUID strings that are currently collapsed into rails
    @Published var collapsedSidebarIDs: Set<String> {
        didSet { save() }
    }
    @Published var githubPAT: String {
        didSet { save() }
    }
    @Published var fileTreeMode: FileTreeMode {
        didSet { save() }
    }
    @Published var pinnedItems: [PinnedItem] {
        didSet { save() }
    }
    @Published var defaultEditMode: Bool {
        didSet { save() }
    }
    @Published var hideMarkdownWhileEditing: Bool {
        didSet { save() }
    }

    // MARK: - Sidebar Helpers

    var leftSidebars:  [Sidebar] { sidebars.filter { $0.position == .left  } }
    var rightSidebars: [Sidebar] { sidebars.filter { $0.position == .right } }

    /// Panes not assigned to any sidebar
    var availablePanes: [SidebarPane] {
        let used = Set(sidebars.flatMap { $0.panes })
        return SidebarPane.allCases.filter { !used.contains($0) }
    }

    /// Move a pane to a sidebar (removes it from wherever it currently lives first)
    func assignPane(_ pane: SidebarPane, toSidebar id: UUID) {
        var updated = sidebars
        for i in updated.indices { updated[i].panes.removeAll { $0 == pane } }
        if let i = updated.firstIndex(where: { $0.id == id }),
           !updated[i].panes.contains(pane) {
            updated[i].panes.append(pane)
        }
        sidebars = updated
    }

    /// Move a pane to a sidebar at a specific insertion index.
    func movePane(_ pane: SidebarPane, toSidebar id: UUID, at insertionIndex: Int) {
        var updated = sidebars
        var removedFromSameSidebarBeforeTarget = false

        for i in updated.indices {
            if updated[i].id == id,
               let existingIndex = updated[i].panes.firstIndex(of: pane) {
                updated[i].panes.remove(at: existingIndex)
                removedFromSameSidebarBeforeTarget = true
            } else {
                updated[i].panes.removeAll { $0 == pane }
            }
        }

        if let targetSidebarIndex = updated.firstIndex(where: { $0.id == id }) {
            let panes = updated[targetSidebarIndex].panes
            let adjustedIndex = min(
                max(0, insertionIndex - (removedFromSameSidebarBeforeTarget ? 1 : 0)),
                panes.count
            )
            updated[targetSidebarIndex].panes.insert(pane, at: adjustedIndex)
        }

        sidebars = updated
    }

    /// Remove a pane from a specific sidebar
    func removePane(_ pane: SidebarPane, fromSidebar id: UUID) {
        var updated = sidebars
        if let i = updated.firstIndex(where: { $0.id == id }) {
            updated[i].panes.removeAll { $0 == pane }
        }
        sidebars = updated
    }

    func isSidebarCollapsed(_ id: UUID) -> Bool {
        collapsedSidebarIDs.contains(id.uuidString)
    }

    func toggleSidebarCollapsed(_ id: UUID) {
        let key = id.uuidString
        if collapsedSidebarIDs.contains(key) {
            collapsedSidebarIDs.remove(key)
        } else {
            collapsedSidebarIDs.insert(key)
        }
    }

    var hasGitHubPAT: Bool {
        !githubPAT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Apply a saved pane-assignment dictionary to the fixed sidebar list.
    static func applyPaneAssignments(_ assignments: [String: [SidebarPane]]?) -> [Sidebar] {
        guard let assignments else { return FixedSidebar.all }
        return FixedSidebar.all.map { sidebar in
            let key = sidebar.id.uuidString
            if let panes = assignments[key] {
                return Sidebar(id: sidebar.id, position: sidebar.position, panes: panes)
            }
            return sidebar
        }
    }

    static let defaultPaneHeights: [String: CGFloat] = [
        "files":    400,
        "links":    200,
        "terminal": 300,
        "tags":     200,
        "graph":    300,
    ]

    let configPath: String
    let vaultRootURL: URL?
    let globalConfigPath: String?

    /// Debounced save work item to prevent excessive disk writes (e.g., during resize drags)
    private var pendingSave: DispatchWorkItem?
    private static let saveDebounceInterval: TimeInterval = 0.5

    /// Whether to use the legacy single-file mode (for backward compatibility)
    private var useLegacyMode: Bool {
        vaultRootURL == nil && globalConfigPath == nil
    }

    private struct Config: Codable {
        var onBootCommand: String
        var fileExtensionFilter: String
        var hiddenFileFolderFilter: String?
        var templatesDirectory: String
        var dailyNotesEnabled: Bool?
        var dailyNotesFolder: String?
        var dailyNotesTemplate: String?
        var dailyNotesOpenOnStartup: Bool?
        var autoSave: Bool
        var autoPush: Bool
        var sidebarPaneHeights: [String: CGFloat]?
        var collapsedPanes: [String]?
        var collapsedSidebarIDs: [String]?
        /// Pane assignments: maps sidebar UUID string -> [SidebarPane]
        var sidebarPaneAssignments: [String: [SidebarPane]]?
        var githubPAT: String?
        var fileTreeMode: String?
        var pinnedItems: [PinnedItem]?
        var defaultEditMode: Bool?
        var hideMarkdownWhileEditing: Bool?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            onBootCommand = try container.decode(String.self, forKey: .onBootCommand)
            fileExtensionFilter = try container.decode(String.self, forKey: .fileExtensionFilter)
            hiddenFileFolderFilter = try container.decodeIfPresent(String.self, forKey: .hiddenFileFolderFilter)
            templatesDirectory = try container.decodeIfPresent(String.self, forKey: .templatesDirectory) ?? "templates"
            dailyNotesEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyNotesEnabled)
            dailyNotesFolder = try container.decodeIfPresent(String.self, forKey: .dailyNotesFolder)
            dailyNotesTemplate = try container.decodeIfPresent(String.self, forKey: .dailyNotesTemplate)
            dailyNotesOpenOnStartup = try container.decodeIfPresent(Bool.self, forKey: .dailyNotesOpenOnStartup)
            autoSave = try container.decodeIfPresent(Bool.self, forKey: .autoSave) ?? false
            autoPush = try container.decodeIfPresent(Bool.self, forKey: .autoPush) ?? false
            sidebarPaneHeights = try container.decodeIfPresent([String: CGFloat].self, forKey: .sidebarPaneHeights)
            collapsedPanes = try container.decodeIfPresent([String].self, forKey: .collapsedPanes)
            collapsedSidebarIDs = try container.decodeIfPresent([String].self, forKey: .collapsedSidebarIDs)
            sidebarPaneAssignments = try container.decodeIfPresent([String: [SidebarPane]].self, forKey: .sidebarPaneAssignments)
            githubPAT = try container.decodeIfPresent(String.self, forKey: .githubPAT)
            fileTreeMode = try container.decodeIfPresent(String.self, forKey: .fileTreeMode)
            pinnedItems = try container.decodeIfPresent([PinnedItem].self, forKey: .pinnedItems)
            defaultEditMode = try container.decodeIfPresent(Bool.self, forKey: .defaultEditMode)
            hideMarkdownWhileEditing = try container.decodeIfPresent(Bool.self, forKey: .hideMarkdownWhileEditing)
        }
    }

    /// Config for vault-specific settings (everything except sensitive data)
    private struct VaultConfig: Codable {
        var onBootCommand: String
        var fileExtensionFilter: String
        var hiddenFileFolderFilter: String?
        var templatesDirectory: String
        var dailyNotesEnabled: Bool?
        var dailyNotesFolder: String?
        var dailyNotesTemplate: String?
        var dailyNotesOpenOnStartup: Bool?
        var autoSave: Bool
        var autoPush: Bool
        var pinnedItems: [PinnedItem]?
        var defaultEditMode: Bool?
        var hideMarkdownWhileEditing: Bool?

        init(
            onBootCommand: String,
            fileExtensionFilter: String,
            hiddenFileFolderFilter: String?,
            templatesDirectory: String,
            dailyNotesEnabled: Bool?,
            dailyNotesFolder: String?,
            dailyNotesTemplate: String?,
            dailyNotesOpenOnStartup: Bool?,
            autoSave: Bool,
            autoPush: Bool,
            pinnedItems: [PinnedItem]?,
            defaultEditMode: Bool?,
            hideMarkdownWhileEditing: Bool?
        ) {
            self.onBootCommand = onBootCommand
            self.fileExtensionFilter = fileExtensionFilter
            self.hiddenFileFolderFilter = hiddenFileFolderFilter
            self.templatesDirectory = templatesDirectory
            self.dailyNotesEnabled = dailyNotesEnabled
            self.dailyNotesFolder = dailyNotesFolder
            self.dailyNotesTemplate = dailyNotesTemplate
            self.dailyNotesOpenOnStartup = dailyNotesOpenOnStartup
            self.autoSave = autoSave
            self.autoPush = autoPush
            self.pinnedItems = pinnedItems
            self.defaultEditMode = defaultEditMode
            self.hideMarkdownWhileEditing = hideMarkdownWhileEditing
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            onBootCommand = try container.decode(String.self, forKey: .onBootCommand)
            fileExtensionFilter = try container.decode(String.self, forKey: .fileExtensionFilter)
            hiddenFileFolderFilter = try container.decodeIfPresent(String.self, forKey: .hiddenFileFolderFilter)
            templatesDirectory = try container.decodeIfPresent(String.self, forKey: .templatesDirectory) ?? "templates"
            dailyNotesEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyNotesEnabled)
            dailyNotesFolder = try container.decodeIfPresent(String.self, forKey: .dailyNotesFolder)
            dailyNotesTemplate = try container.decodeIfPresent(String.self, forKey: .dailyNotesTemplate)
            dailyNotesOpenOnStartup = try container.decodeIfPresent(Bool.self, forKey: .dailyNotesOpenOnStartup)
            autoSave = try container.decodeIfPresent(Bool.self, forKey: .autoSave) ?? false
            autoPush = try container.decodeIfPresent(Bool.self, forKey: .autoPush) ?? false
            pinnedItems = try container.decodeIfPresent([PinnedItem].self, forKey: .pinnedItems)
            defaultEditMode = try container.decodeIfPresent(Bool.self, forKey: .defaultEditMode)
            hideMarkdownWhileEditing = try container.decodeIfPresent(Bool.self, forKey: .hideMarkdownWhileEditing)
        }
    }

    /// Config for machine-local settings only
    private struct GlobalConfig: Codable {
        var githubPAT: String?
        var sidebarPaneHeights: [String: CGFloat]?
        var collapsedPanes: [String]?
        var collapsedSidebarIDs: [String]?
        var sidebarPaneAssignments: [String: [SidebarPane]]?
        var fileTreeMode: String?

        init(
            githubPAT: String?,
            sidebarPaneHeights: [String: CGFloat]?,
            collapsedPanes: [String]?,
            collapsedSidebarIDs: [String]?,
            sidebarPaneAssignments: [String: [SidebarPane]]?,
            fileTreeMode: String?
        ) {
            self.githubPAT = githubPAT
            self.sidebarPaneHeights = sidebarPaneHeights
            self.collapsedPanes = collapsedPanes
            self.collapsedSidebarIDs = collapsedSidebarIDs
            self.sidebarPaneAssignments = sidebarPaneAssignments
            self.fileTreeMode = fileTreeMode
        }
    }

    /// Initialize with default config path in Application Support (legacy mode for backward compatibility)
    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let configDir = appSupport.appendingPathComponent("Synapse")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configPath = configDir.appendingPathComponent(Self.globalSettingsFilename).path
        self.init(configPath: configPath)
    }

    /// Initialize with a specific config path (legacy mode, useful for testing)
    init(configPath: String) {
        self.configPath = configPath
        self.vaultRootURL = nil
        self.globalConfigPath = nil

        // Load existing config or use defaults
        if let config = Self.loadConfig(from: configPath) {
            self.onBootCommand = config.onBootCommand
            self.fileExtensionFilter = config.fileExtensionFilter
            self.hiddenFileFolderFilter = config.hiddenFileFolderFilter ?? ""
            self.templatesDirectory = config.templatesDirectory
            self.dailyNotesEnabled = config.dailyNotesEnabled ?? false
            self.dailyNotesFolder = config.dailyNotesFolder ?? "daily"
            self.dailyNotesTemplate = config.dailyNotesTemplate ?? ""
            self.dailyNotesOpenOnStartup = config.dailyNotesOpenOnStartup ?? false
            self.autoSave = config.autoSave
            self.autoPush = config.autoPush
            self.sidebars = Self.applyPaneAssignments(config.sidebarPaneAssignments)
            self.sidebarPaneHeights = config.sidebarPaneHeights ?? Self.defaultPaneHeights
            self.collapsedPanes = Set(config.collapsedPanes ?? [])
            self.collapsedSidebarIDs = Set(config.collapsedSidebarIDs ?? [FixedSidebar.right2ID.uuidString])
            self.githubPAT = config.githubPAT ?? ""
            self.fileTreeMode = FileTreeMode(rawValue: config.fileTreeMode ?? "") ?? .folder
            self.pinnedItems = config.pinnedItems ?? []
            self.defaultEditMode = config.defaultEditMode ?? true
            self.hideMarkdownWhileEditing = config.hideMarkdownWhileEditing ?? false
        } else {
            self.onBootCommand = ""
            self.fileExtensionFilter = "*.md, *.txt"
            self.hiddenFileFolderFilter = ""
            self.templatesDirectory = "templates"
            self.dailyNotesEnabled = false
            self.dailyNotesFolder = "daily"
            self.dailyNotesTemplate = ""
            self.dailyNotesOpenOnStartup = false
            self.autoSave = false
            self.autoPush = false
            self.sidebars = FixedSidebar.all
            self.sidebarPaneHeights = Self.defaultPaneHeights
            self.collapsedPanes = []
            self.collapsedSidebarIDs = [FixedSidebar.right2ID.uuidString]
            self.githubPAT = ""
            self.fileTreeMode = .folder
            self.pinnedItems = []
            self.defaultEditMode = true
            self.hideMarkdownWhileEditing = false
        }
    }

    /// Initialize with vault root - stores settings in .noted/settings.yml
    /// - Parameters:
    ///   - vaultRoot: The vault root URL (nil means use defaults)
    ///   - globalConfigPath: Optional path for global/sensitive settings (defaults to Application Support)
    convenience init(vaultRoot: URL?, globalConfigPath: String? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let configDir = appSupport.appendingPathComponent("Synapse")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let defaultGlobalPath = configDir.appendingPathComponent(Self.globalSettingsFilename).path

        self.init(
            vaultRoot: vaultRoot,
            globalConfigPath: globalConfigPath ?? defaultGlobalPath
        )
    }

    /// Full initializer with vault root and global config path
    init(vaultRoot: URL?, globalConfigPath: String) {
        self.configPath = vaultRoot?.appendingPathComponent(".noted/\(Self.vaultSettingsFilename)").path ?? globalConfigPath
        self.vaultRootURL = vaultRoot
        self.globalConfigPath = globalConfigPath

        if let vaultRoot = vaultRoot {
            // Vault mode: load from both vault config and global config
            let vaultConfigPath = vaultRoot.appendingPathComponent(".noted/\(Self.vaultSettingsFilename)").path

            // Create .noted folder and settings file if they don't exist
            let notedDir = vaultRoot.appendingPathComponent(".noted")
            if !FileManager.default.fileExists(atPath: notedDir.path) {
                try? FileManager.default.createDirectory(at: notedDir, withIntermediateDirectories: true)
            }

            // Load vault-specific settings
            if let vaultConfig = Self.loadVaultConfig(from: vaultConfigPath) {
                self.onBootCommand = vaultConfig.onBootCommand
                self.fileExtensionFilter = vaultConfig.fileExtensionFilter
                self.hiddenFileFolderFilter = vaultConfig.hiddenFileFolderFilter ?? ""
                self.templatesDirectory = vaultConfig.templatesDirectory
                self.dailyNotesEnabled = vaultConfig.dailyNotesEnabled ?? false
                self.dailyNotesFolder = vaultConfig.dailyNotesFolder ?? "daily"
                self.dailyNotesTemplate = vaultConfig.dailyNotesTemplate ?? ""
                self.dailyNotesOpenOnStartup = vaultConfig.dailyNotesOpenOnStartup ?? false
                self.autoSave = vaultConfig.autoSave
                self.autoPush = vaultConfig.autoPush
                self.pinnedItems = vaultConfig.pinnedItems ?? []
                self.defaultEditMode = vaultConfig.defaultEditMode ?? true
                self.hideMarkdownWhileEditing = vaultConfig.hideMarkdownWhileEditing ?? false
            } else {
                // No vault config exists yet - use defaults
                self.onBootCommand = ""
                self.fileExtensionFilter = "*.md, *.txt"
                self.hiddenFileFolderFilter = ""
                self.templatesDirectory = "templates"
                self.dailyNotesEnabled = false
                self.dailyNotesFolder = "daily"
                self.dailyNotesTemplate = ""
                self.dailyNotesOpenOnStartup = false
                self.autoSave = false
                self.autoPush = false
                self.pinnedItems = []
                self.defaultEditMode = true
                self.hideMarkdownWhileEditing = false
            }

            self.sidebars = FixedSidebar.all
            self.sidebarPaneHeights = Self.defaultPaneHeights
            self.collapsedPanes = []
            self.collapsedSidebarIDs = [FixedSidebar.right2ID.uuidString]
            self.fileTreeMode = .folder

            // Load global/machine-local settings
            if let globalConfig = Self.loadGlobalConfig(from: globalConfigPath) {
                self.githubPAT = globalConfig.githubPAT ?? ""
                self.sidebars = Self.applyPaneAssignments(globalConfig.sidebarPaneAssignments)
                self.sidebarPaneHeights = globalConfig.sidebarPaneHeights ?? Self.defaultPaneHeights
                self.collapsedPanes = Set(globalConfig.collapsedPanes ?? [])
                self.collapsedSidebarIDs = Set(globalConfig.collapsedSidebarIDs ?? [FixedSidebar.right2ID.uuidString])
                self.fileTreeMode = FileTreeMode(rawValue: globalConfig.fileTreeMode ?? "") ?? self.fileTreeMode
            } else {
                self.githubPAT = ""
            }
        } else {
            // No vault mode: use all defaults
            self.onBootCommand = ""
            self.fileExtensionFilter = "*.md, *.txt"
            self.hiddenFileFolderFilter = ""
            self.templatesDirectory = "templates"
            self.dailyNotesEnabled = false
            self.dailyNotesFolder = "daily"
            self.dailyNotesTemplate = ""
            self.dailyNotesOpenOnStartup = false
            self.autoSave = false
            self.autoPush = false
            self.sidebars = FixedSidebar.all
            self.sidebarPaneHeights = Self.defaultPaneHeights
            self.collapsedPanes = []
            self.collapsedSidebarIDs = [FixedSidebar.right2ID.uuidString]
            self.githubPAT = ""
            self.fileTreeMode = .folder
            self.pinnedItems = []
            self.defaultEditMode = true
            self.hideMarkdownWhileEditing = false
        }
    }

    /// Parse fileExtensionFilter into an array of extension strings
    var parsedExtensions: [String] {
        let filter = fileExtensionFilter.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty filter or wildcard means show all files
        if filter.isEmpty || filter == "*" {
            return []
        }

        // Split by comma and process each pattern
        return filter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { pattern -> String? in
                // Handle patterns like "*.md" -> extract "md"
                if pattern.hasPrefix("*.") {
                    let ext = String(pattern.dropFirst(2))
                    return ext.isEmpty ? nil : ext.lowercased()
                }
                // Also accept bare extensions like "md"
                return pattern.isEmpty ? nil : pattern.lowercased()
            }
    }

    var parsedHiddenPatterns: [String] {
        hiddenFileFolderFilter
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func shouldHideItem(named name: String) -> Bool {
        let patterns = parsedHiddenPatterns
        guard !patterns.isEmpty else { return false }

        return patterns.contains { pattern in
            wildcardMatches(name, pattern: pattern)
        }
    }

    private func wildcardMatches(_ name: String, pattern: String) -> Bool {
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        return name.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Check if a file should be shown based on the current extension filter
    func shouldShowFile(_ url: URL, relativeTo root: URL? = nil) -> Bool {
        if shouldHideItem(named: url.lastPathComponent) {
            return false
        }

        if let root,
           isHiddenByAncestor(url, relativeTo: root) {
            return false
        }

        let extensions = parsedExtensions

        // Empty extensions means show all files
        if extensions.isEmpty {
            return true
        }

        let fileExt = url.pathExtension.lowercased()
        return extensions.contains(fileExt)
    }

    private func isHiddenByAncestor(_ url: URL, relativeTo root: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        let standardizedRoot = root.standardizedFileURL
        let urlComponents = standardizedURL.pathComponents
        let rootComponents = standardizedRoot.pathComponents

        guard urlComponents.starts(with: rootComponents) else {
            return false
        }

        let relativeComponents = Array(urlComponents.dropFirst(rootComponents.count).dropLast())
        return relativeComponents.contains { shouldHideItem(named: $0) }
    }

    /// Schedule a debounced save to disk, coalescing rapid mutations.
    /// Snapshot all values on the main thread, then serialize on a background thread.
    private func save() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            flush(); return
        }
        pendingSave?.cancel()
        let snap = SaveSnapshot(from: self)
        let work = DispatchWorkItem {
            DispatchQueue.global(qos: .utility).async { snap.write() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDebounceInterval, execute: work)
    }

    private func flush() {
        SaveSnapshot(from: self).write()
    }

    // Value-type snapshot so background thread never touches SettingsManager.
    private struct SaveSnapshot {
        let useLegacyMode: Bool
        let onBootCommand: String
        let fileExtensionFilter: String
        let hiddenFileFolderFilter: String
        let templatesDirectory: String
        let dailyNotesEnabled: Bool
        let dailyNotesFolder: String
        let dailyNotesTemplate: String
        let dailyNotesOpenOnStartup: Bool
        let autoSave: Bool
        let autoPush: Bool
        let sidebarPaneAssignments: [String: [SidebarPane]]
        let sidebarPaneHeights: [String: CGFloat]
        let collapsedPanes: [String]
        let collapsedSidebarIDs: [String]
        let githubPAT: String
        let fileTreeMode: FileTreeMode
        let pinnedItems: [PinnedItem]
        let defaultEditMode: Bool
        let hideMarkdownWhileEditing: Bool
        let configPath: String
        let vaultRootURL: URL?
        let globalConfigPath: String?

        init(from s: SettingsManager) {
            useLegacyMode         = s.useLegacyMode
            onBootCommand         = s.onBootCommand
            fileExtensionFilter   = s.fileExtensionFilter
            hiddenFileFolderFilter = s.hiddenFileFolderFilter
            templatesDirectory    = s.templatesDirectory
            dailyNotesEnabled     = s.dailyNotesEnabled
            dailyNotesFolder      = s.dailyNotesFolder
            dailyNotesTemplate    = s.dailyNotesTemplate
            dailyNotesOpenOnStartup = s.dailyNotesOpenOnStartup
            autoSave              = s.autoSave
            autoPush              = s.autoPush
            // Snapshot pane assignments as a dict keyed by sidebar UUID string
            sidebarPaneAssignments = Dictionary(uniqueKeysWithValues: s.sidebars.map { ($0.id.uuidString, $0.panes) })
            sidebarPaneHeights    = s.sidebarPaneHeights
            collapsedPanes        = Array(s.collapsedPanes)
            collapsedSidebarIDs   = Array(s.collapsedSidebarIDs)
            githubPAT             = s.githubPAT
            fileTreeMode          = s.fileTreeMode
            pinnedItems           = s.pinnedItems
            defaultEditMode       = s.defaultEditMode
            hideMarkdownWhileEditing = s.hideMarkdownWhileEditing
            configPath            = s.configPath
            vaultRootURL          = s.vaultRootURL
            globalConfigPath      = s.globalConfigPath
        }

        func write() {
            if useLegacyMode {
                writeLegacy()
            } else if vaultRootURL != nil {
                writeVault()
            }
        }

        private func writeLegacy() {
            // Encode a minimal Codable struct so we don't need the full Config init chain.
            struct LegacyFile: Encodable {
                var onBootCommand: String
                var fileExtensionFilter: String
                var hiddenFileFolderFilter: String?
                var templatesDirectory: String
                var dailyNotesEnabled: Bool?
                var dailyNotesFolder: String?
                var dailyNotesTemplate: String?
                var dailyNotesOpenOnStartup: Bool?
                var autoSave: Bool
                var autoPush: Bool
                var sidebarPaneAssignments: [String: [SidebarPane]]?
                var sidebarPaneHeights: [String: CGFloat]?
                var collapsedPanes: [String]?
                var collapsedSidebarIDs: [String]?
                var githubPAT: String?
                var fileTreeMode: String?
                var pinnedItems: [PinnedItem]?
                var defaultEditMode: Bool?
                var hideMarkdownWhileEditing: Bool?
            }
            let file = LegacyFile(
                onBootCommand: onBootCommand,
                fileExtensionFilter: fileExtensionFilter,
                hiddenFileFolderFilter: hiddenFileFolderFilter.isEmpty ? nil : hiddenFileFolderFilter,
                templatesDirectory: templatesDirectory,
                dailyNotesEnabled: dailyNotesEnabled,
                dailyNotesFolder: dailyNotesFolder,
                dailyNotesTemplate: dailyNotesTemplate,
                dailyNotesOpenOnStartup: dailyNotesOpenOnStartup,
                autoSave: autoSave,
                autoPush: autoPush,
                sidebarPaneAssignments: sidebarPaneAssignments,
                sidebarPaneHeights: sidebarPaneHeights.isEmpty ? nil : sidebarPaneHeights,
                collapsedPanes: collapsedPanes.isEmpty ? nil : collapsedPanes,
                collapsedSidebarIDs: collapsedSidebarIDs.isEmpty ? nil : collapsedSidebarIDs,
                githubPAT: githubPAT.isEmpty ? nil : githubPAT,
                fileTreeMode: fileTreeMode.rawValue,
                pinnedItems: pinnedItems.isEmpty ? nil : pinnedItems,
                defaultEditMode: defaultEditMode,
                hideMarkdownWhileEditing: hideMarkdownWhileEditing ? true : nil
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(file) else { return }
            let url = URL(fileURLWithPath: configPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }

        private func writeVault() {
            guard let vaultRootURL else { return }
            let vaultConfig = VaultConfig(
                onBootCommand: onBootCommand,
                fileExtensionFilter: fileExtensionFilter,
                hiddenFileFolderFilter: hiddenFileFolderFilter.isEmpty ? nil : hiddenFileFolderFilter,
                templatesDirectory: templatesDirectory,
                dailyNotesEnabled: dailyNotesEnabled,
                dailyNotesFolder: dailyNotesFolder,
                dailyNotesTemplate: dailyNotesTemplate,
                dailyNotesOpenOnStartup: dailyNotesOpenOnStartup,
                autoSave: autoSave,
                autoPush: autoPush,
                pinnedItems: pinnedItems.isEmpty ? nil : pinnedItems,
                defaultEditMode: defaultEditMode,
                hideMarkdownWhileEditing: hideMarkdownWhileEditing ? true : nil
            )
            let notedDir = vaultRootURL.appendingPathComponent(".noted")
            try? FileManager.default.createDirectory(at: notedDir, withIntermediateDirectories: true)
            let vaultConfigURL = notedDir.appendingPathComponent(SettingsManager.vaultSettingsFilename)
            guard let vaultYAML = try? YAMLEncoder().encode(vaultConfig) else { return }
            try? vaultYAML.write(to: vaultConfigURL, atomically: true, encoding: .utf8)

            guard let globalConfigPath else { return }
            let globalConfig = GlobalConfig(
                githubPAT: githubPAT.isEmpty ? nil : githubPAT,
                sidebarPaneHeights: sidebarPaneHeights.isEmpty ? nil : sidebarPaneHeights,
                collapsedPanes: collapsedPanes.isEmpty ? nil : collapsedPanes,
                collapsedSidebarIDs: collapsedSidebarIDs.isEmpty ? nil : collapsedSidebarIDs,
                sidebarPaneAssignments: sidebarPaneAssignments,
                fileTreeMode: fileTreeMode.rawValue
            )
            guard let globalYAML = try? YAMLEncoder().encode(globalConfig) else { return }
            let globalURL = URL(fileURLWithPath: globalConfigPath)
            try? FileManager.default.createDirectory(at: globalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? globalYAML.write(to: globalURL, atomically: true, encoding: .utf8)
        }
    }

    /// Load legacy config from disk
    private static func loadConfig(from path: String) -> Config? {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        // Try JSON first, then YAML (older format)
        if let config = try? JSONDecoder().decode(Config.self, from: data) { return config }
        if let yaml = String(data: data, encoding: .utf8),
           let config = try? YAMLDecoder().decode(Config.self, from: yaml) { return config }
        return nil
    }

    /// Load vault-specific config from disk
    private static func loadVaultConfig(from path: String) -> VaultConfig? {
        guard FileManager.default.fileExists(atPath: path),
              let yaml = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
            return nil
        }

        return try? YAMLDecoder().decode(VaultConfig.self, from: yaml)
    }

    /// Load global/sensitive config from disk
    private static func loadGlobalConfig(from path: String) -> GlobalConfig? {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        if let yaml = String(data: data, encoding: .utf8),
           let config = try? YAMLDecoder().decode(GlobalConfig.self, from: yaml) {
            return config
        }

        return try? JSONDecoder().decode(GlobalConfig.self, from: data)
    }


}
