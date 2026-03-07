import SwiftUI
import Combine

struct NoteLinkRelationships {
    let outbound: [URL]
    let inbound: [URL]
    let unresolved: [String]
}

class AppState: ObservableObject {
    @Published var rootURL: URL?
    @Published var selectedFile: URL?
    @Published var fileContent: String = ""
    @Published var isDirty: Bool = false
    @Published var allFiles: [URL] = []
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    private var history: [URL] = []
    private var historyIndex: Int = -1
    private var navigatingHistory = false
    private var lastObservedModificationDate: Date?

    private var saveCancellable: AnyCancellable?
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var filePollCancellable: AnyCancellable?
    private var watchedFD: Int32 = -1

    init() {
        saveCancellable = $fileContent
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] content in
                guard let self, self.isDirty else { return }
                self.saveCurrentFile(content: content)
            }
    }

    private func startWatching(_ url: URL) {
        stopWatching()
        lastObservedModificationDate = fileModificationDate(for: url)

        let dirPath = url.deletingLastPathComponent().path
        let fd = open(dirPath, O_EVTONLY)
        if fd >= 0 {
            watchedFD = fd
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .extend, .attrib],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                guard let self else { return }
                self.refreshAllFiles()
                self.reloadSelectedFileFromDiskIfNeeded(force: true)
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            fileWatcher = source
        }

        filePollCancellable = Timer.publish(every: 0.75, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.reloadSelectedFileFromDiskIfNeeded()
            }
    }

    private func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        filePollCancellable?.cancel()
        filePollCancellable = nil
        lastObservedModificationDate = nil
        watchedFD = -1
    }

    private func fileModificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func noteTitle(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func normalizedNoteReference(_ value: String) -> String {
        value
            .split(separator: "|", maxSplits: 1)
            .first
            .map(String.init)?
            .split(separator: "#", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func wikiLinks(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let raw = nsText.substring(with: match.range(at: 1))
            let normalized = normalizedNoteReference(raw)
            return normalized.isEmpty ? nil : normalized
        }
    }

    private func noteIndex() -> [String: URL] {
        Dictionary(uniqueKeysWithValues: allFiles.map { (normalizedNoteReference(noteTitle(for: $0)), $0) })
    }

    func relationshipsForSelectedFile() -> NoteLinkRelationships? {
        guard let selectedFile else { return nil }

        let index = noteIndex()
        var seenOutbound = Set<URL>()
        var outbound: [URL] = []
        var unresolved: [String] = []
        var seenMissing = Set<String>()

        for link in wikiLinks(in: fileContent) {
            if let url = index[link] {
                if seenOutbound.insert(url).inserted {
                    outbound.append(url)
                }
            } else if seenMissing.insert(link).inserted {
                unresolved.append(link)
            }
        }

        let selectedTitle = normalizedNoteReference(noteTitle(for: selectedFile))
        var inbound: [URL] = []
        for url in allFiles where url != selectedFile {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if wikiLinks(in: content).contains(selectedTitle) {
                inbound.append(url)
            }
        }

        return NoteLinkRelationships(outbound: outbound, inbound: inbound, unresolved: unresolved)
    }

    private func reloadSelectedFileFromDiskIfNeeded(force: Bool = false) {
        guard !isDirty, let url = selectedFile else { return }
        guard let fresh = try? String(contentsOf: url, encoding: .utf8) else { return }

        let currentModificationDate = fileModificationDate(for: url)
        let didChangeOnDisk = currentModificationDate != lastObservedModificationDate || fresh != fileContent
        guard force || didChangeOnDisk else { return }

        fileContent = fresh
        isDirty = false
        lastObservedModificationDate = currentModificationDate
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to open in Noted"
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func openFolder(_ url: URL) {
        stopWatching()
        rootURL = url
        selectedFile = nil
        fileContent = ""
        isDirty = false
        history = []
        historyIndex = -1
        updateHistoryState()
        refreshAllFiles()
    }

    func refreshAllFiles() {
        guard let root = rootURL else { allFiles = []; return }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        allFiles = enumerator.compactMap { $0 as? URL }.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "md" || ext == "markdown"
        }
    }

    func openFile(_ url: URL) {
        if isDirty { saveCurrentFile(content: fileContent) }
        if !navigatingHistory {
            if historyIndex < history.count - 1 {
                history = Array(history.prefix(historyIndex + 1))
            }
            history.append(url)
            historyIndex = history.count - 1
        }
        selectedFile = url
        fileContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        isDirty = false
        startWatching(url)
        updateHistoryState()
    }

    func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        navigatingHistory = true
        openFile(history[historyIndex])
        navigatingHistory = false
    }

    func goForward() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        navigatingHistory = true
        openFile(history[historyIndex])
        navigatingHistory = false
    }

    private func updateHistoryState() {
        canGoBack = historyIndex > 0
        canGoForward = historyIndex < history.count - 1
    }

    func saveCurrentFile(content: String) {
        guard let url = selectedFile else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
        lastObservedModificationDate = fileModificationDate(for: url)
    }
}
