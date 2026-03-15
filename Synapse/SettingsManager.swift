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
    @Published var leftSidebarPanes: [SidebarPane] {
        didSet { save() }
    }
    @Published var rightSidebarPanes: [SidebarPane] {
        didSet { save() }
    }
    /// Persisted pane heights keyed by SidebarPane rawValue, for the left sidebar
    @Published var leftPaneHeights: [String: CGFloat] {
        didSet { save() }
    }
    /// Persisted pane heights keyed by SidebarPane rawValue, for the right sidebar
    @Published var rightPaneHeights: [String: CGFloat] {
        didSet { save() }
    }
    /// Set of pane rawValues that are currently collapsed
    @Published var collapsedPanes: Set<String> {
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

    var hasGitHubPAT: Bool {
        !githubPAT.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
        var leftSidebarPanes: [SidebarPane]?
        var rightSidebarPanes: [SidebarPane]?
        var leftPaneHeights: [String: CGFloat]?
        var rightPaneHeights: [String: CGFloat]?
        var collapsedPanes: [String]?
        var githubPAT: String?
        var fileTreeMode: String?
        var pinnedItems: [PinnedItem]?

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
            leftSidebarPanes: [SidebarPane]?,
            rightSidebarPanes: [SidebarPane]?,
            leftPaneHeights: [String: CGFloat]?,
            rightPaneHeights: [String: CGFloat]?,
            collapsedPanes: [String]?,
            githubPAT: String?,
            fileTreeMode: String?,
            pinnedItems: [PinnedItem]?
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
            self.leftSidebarPanes = leftSidebarPanes
            self.rightSidebarPanes = rightSidebarPanes
            self.leftPaneHeights = leftPaneHeights
            self.rightPaneHeights = rightPaneHeights
            self.collapsedPanes = collapsedPanes
            self.githubPAT = githubPAT
            self.fileTreeMode = fileTreeMode
            self.pinnedItems = pinnedItems
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
            leftSidebarPanes = try container.decodeIfPresent([SidebarPane].self, forKey: .leftSidebarPanes)
            rightSidebarPanes = try container.decodeIfPresent([SidebarPane].self, forKey: .rightSidebarPanes)
            leftPaneHeights = try container.decodeIfPresent([String: CGFloat].self, forKey: .leftPaneHeights)
            rightPaneHeights = try container.decodeIfPresent([String: CGFloat].self, forKey: .rightPaneHeights)
            collapsedPanes = try container.decodeIfPresent([String].self, forKey: .collapsedPanes)
            githubPAT = try container.decodeIfPresent(String.self, forKey: .githubPAT)
            fileTreeMode = try container.decodeIfPresent(String.self, forKey: .fileTreeMode)
            pinnedItems = try container.decodeIfPresent([PinnedItem].self, forKey: .pinnedItems)
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
            pinnedItems: [PinnedItem]?
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
        }
    }

    /// Config for machine-local settings only
    private struct GlobalConfig: Codable {
        var githubPAT: String?
        var leftSidebarPanes: [SidebarPane]?
        var rightSidebarPanes: [SidebarPane]?
        var leftPaneHeights: [String: CGFloat]?
        var rightPaneHeights: [String: CGFloat]?
        var collapsedPanes: [String]?
        var fileTreeMode: String?

        init(
            githubPAT: String?,
            leftSidebarPanes: [SidebarPane]?,
            rightSidebarPanes: [SidebarPane]?,
            leftPaneHeights: [String: CGFloat]?,
            rightPaneHeights: [String: CGFloat]?,
            collapsedPanes: [String]?,
            fileTreeMode: String?
        ) {
            self.githubPAT = githubPAT
            self.leftSidebarPanes = leftSidebarPanes
            self.rightSidebarPanes = rightSidebarPanes
            self.leftPaneHeights = leftPaneHeights
            self.rightPaneHeights = rightPaneHeights
            self.collapsedPanes = collapsedPanes
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
            self.leftSidebarPanes = config.leftSidebarPanes ?? [.files, .tags, .links]
            self.rightSidebarPanes = config.rightSidebarPanes ?? [.terminal]
            self.leftPaneHeights = config.leftPaneHeights ?? [:]
            self.rightPaneHeights = config.rightPaneHeights ?? [:]
            self.collapsedPanes = Set(config.collapsedPanes ?? [])
            self.githubPAT = config.githubPAT ?? ""
            self.fileTreeMode = FileTreeMode(rawValue: config.fileTreeMode ?? "") ?? .folder
            self.pinnedItems = config.pinnedItems ?? []
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
            self.leftSidebarPanes = [.files, .tags, .links]
            self.rightSidebarPanes = [.terminal]
            self.leftPaneHeights = [:]
            self.rightPaneHeights = [:]
            self.collapsedPanes = []
            self.githubPAT = ""
            self.fileTreeMode = .folder
            self.pinnedItems = []
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
            }

            self.leftSidebarPanes = [.files, .tags, .links]
            self.rightSidebarPanes = [.terminal]
            self.leftPaneHeights = [:]
            self.rightPaneHeights = [:]
            self.collapsedPanes = []
            self.fileTreeMode = .folder

            // Load global/machine-local settings
            if let globalConfig = Self.loadGlobalConfig(from: globalConfigPath) {
                self.githubPAT = globalConfig.githubPAT ?? ""
                self.leftSidebarPanes = globalConfig.leftSidebarPanes ?? self.leftSidebarPanes
                self.rightSidebarPanes = globalConfig.rightSidebarPanes ?? self.rightSidebarPanes
                self.leftPaneHeights = globalConfig.leftPaneHeights ?? self.leftPaneHeights
                self.rightPaneHeights = globalConfig.rightPaneHeights ?? self.rightPaneHeights
                self.collapsedPanes = Set(globalConfig.collapsedPanes ?? Array(self.collapsedPanes))
                self.fileTreeMode = FileTreeMode(rawValue: globalConfig.fileTreeMode ?? "") ?? self.fileTreeMode
            } else {
                self.githubPAT = ""
            }
        } else {
            // No vault mode: use all defaults, including empty githubPAT
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
            self.leftSidebarPanes = [.files, .tags, .links]
            self.rightSidebarPanes = [.terminal]
            self.leftPaneHeights = [:]
            self.rightPaneHeights = [:]
            self.collapsedPanes = []
            self.githubPAT = ""
            self.fileTreeMode = .folder
            self.pinnedItems = []
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
    /// In test environments, saves are performed synchronously to avoid timing issues.
    private func save() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            performSave()
            return
        }
        pendingSave?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        pendingSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDebounceInterval, execute: workItem)
    }

    /// Actually write settings to disk.
    private func performSave() {
        if useLegacyMode {
            // Legacy mode: save everything to single config file
            let config = Config(
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
                leftSidebarPanes: leftSidebarPanes,
                rightSidebarPanes: rightSidebarPanes,
                leftPaneHeights: leftPaneHeights,
                rightPaneHeights: rightPaneHeights,
                collapsedPanes: Array(collapsedPanes),
                githubPAT: githubPAT.isEmpty ? nil : githubPAT,
                fileTreeMode: fileTreeMode.rawValue,
                pinnedItems: pinnedItems.isEmpty ? nil : pinnedItems
            )
            let encoder = Self.makePrettyJSONEncoder()
            guard let data = try? encoder.encode(config) else { return }
            let configURL = URL(fileURLWithPath: configPath)
            let parentDir = configURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try? data.write(to: configURL)
        } else if let vaultRootURL = vaultRootURL {
            // Vault mode: save vault settings to .noted/settings.yml
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
                pinnedItems: pinnedItems.isEmpty ? nil : pinnedItems
            )

            // Save vault-specific settings to .noted/settings.yml
            let notedDir = vaultRootURL.appendingPathComponent(".noted")
            try? FileManager.default.createDirectory(at: notedDir, withIntermediateDirectories: true)
            let vaultConfigPath = notedDir.appendingPathComponent(Self.vaultSettingsFilename)

            guard let vaultYAML = try? YAMLEncoder().encode(vaultConfig) else { return }
            try? vaultYAML.write(to: vaultConfigPath, atomically: true, encoding: .utf8)

            // Save machine-local settings to global config
            if let globalConfigPath = globalConfigPath {
                let globalConfig = GlobalConfig(
                    githubPAT: githubPAT.isEmpty ? nil : githubPAT,
                    leftSidebarPanes: leftSidebarPanes,
                    rightSidebarPanes: rightSidebarPanes,
                    leftPaneHeights: leftPaneHeights,
                    rightPaneHeights: rightPaneHeights,
                    collapsedPanes: Array(collapsedPanes),
                    fileTreeMode: fileTreeMode.rawValue
                )
                guard let globalYAML = try? YAMLEncoder().encode(globalConfig) else { return }
                let globalConfigURL = URL(fileURLWithPath: globalConfigPath)
                let globalParentDir = globalConfigURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: globalParentDir, withIntermediateDirectories: true)
                try? globalYAML.write(to: globalConfigURL, atomically: true, encoding: .utf8)
            }
        }
        // If no vault and not legacy mode, don't save anything (use defaults in memory)
    }

    /// Load legacy config from disk
    private static func loadConfig(from path: String) -> Config? {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        return try? JSONDecoder().decode(Config.self, from: data)
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

    /// Create a JSON encoder with pretty printing enabled
    private static func makePrettyJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
