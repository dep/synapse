import SwiftUI
import Combine

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

    private var saveCancellable: AnyCancellable?
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1

    init() {
        saveCancellable = $fileContent
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] content in
                self?.saveCurrentFile(content: content)
            }
    }

    private func startWatching(_ url: URL) {
        stopWatching()
        let dirPath = url.deletingLastPathComponent().path
        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }
        watchedFD = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, !self.isDirty, let url = self.selectedFile else { return }
            let fresh = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if fresh != self.fileContent {
                self.fileContent = fresh
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }

    private func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        watchedFD = -1
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
    }
}
