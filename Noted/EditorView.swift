import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedFile == nil {
                emptyState
            } else {
                RawEditor(text: $appState.fileContent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Select a file to edit")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Live markdown editor

struct RawEditor: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = LinkAwareTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.textContainer?.widthTracksTextView = true
        textView.allowsUndo = true
        textView.backgroundColor = .textBackgroundColor
        textView.usesFontPanel = false
        textView.usesRuler = false

        // Use NSTextStorageDelegate to detect ALL text changes reliably
        textView.textStorage?.delegate = context.coordinator

        context.coordinator.textView = textView

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? LinkAwareTextView else { return }
        if textView.string != text {
            context.coordinator.suppressSync = true
            let selected = textView.selectedRanges
            textView.setPlainText(text)
            textView.selectedRanges = selected
            context.coordinator.suppressSync = false
        }
        textView.allFiles = appState.allFiles
        textView.onOpenFile = { appState.openFile($0) }
    }

    class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: RawEditor
        weak var textView: LinkAwareTextView?
        var suppressSync = false
        private var stylingScheduled = false
        private var linkCheckScheduled = false

        init(_ parent: RawEditor) { self.parent = parent }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard !suppressSync, editedMask.contains(.editedCharacters) else { return }
            guard let tv = textView else { return }
            let newText = tv.string
            if parent.text != newText {
                parent.text = newText
                parent.appState.isDirty = true
            }
            if !linkCheckScheduled {
                linkCheckScheduled = true
                // Run after NSTextView finalizes selection/caret for this edit.
                DispatchQueue.main.async { [weak self, weak tv] in
                    guard let self, let tv else { return }
                    self.linkCheckScheduled = false
                    tv.checkForLinkTrigger()
                }
            }
            if !stylingScheduled {
                stylingScheduled = true
                DispatchQueue.main.async { [weak self, weak tv] in
                    guard let self, let tv else { return }
                    self.stylingScheduled = false
                    self.suppressSync = true
                    tv.applyMarkdownStyling()
                    self.suppressSync = false
                }
            }
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            return (textView as? LinkAwareTextView)?.handleLinkClick(link) ?? false
        }
    }
}

// MARK: - Markdown styling theme

private enum MarkdownTheme {
    static let body = NSFont.systemFont(ofSize: 15)
    static let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let h1   = NSFont.systemFont(ofSize: 28, weight: .bold)
    static let h2   = NSFont.systemFont(ofSize: 22, weight: .bold)
    static let h3   = NSFont.systemFont(ofSize: 18, weight: .semibold)
    static let h4   = NSFont.systemFont(ofSize: 16, weight: .semibold)
    static let dimColor       = NSColor.secondaryLabelColor
    static let linkColor      = NSColor.linkColor
    static let codeBackground = NSColor.quaternaryLabelColor.withAlphaComponent(0.15)
}

// MARK: - Markdown styling extension

extension LinkAwareTextView {
    func setPlainText(_ plain: String) {
        guard let storage = textStorage else { return }
        storage.beginEditing()
        storage.setAttributedString(NSAttributedString(string: plain))
        storage.endEditing()
        applyMarkdownStyling()
    }

    func applyMarkdownStyling() {
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }
        let text = storage.string as NSString

        storage.beginEditing()

        storage.setAttributes([
            .font: MarkdownTheme.body,
            .foregroundColor: NSColor.labelColor,
        ], range: fullRange)

        let headerPatterns: [(String, NSFont)] = [
            ("^#{6} .+$", MarkdownTheme.h4),
            ("^#{5} .+$", MarkdownTheme.h4),
            ("^#{4} .+$", MarkdownTheme.h4),
            ("^### .+$",  MarkdownTheme.h3),
            ("^## .+$",   MarkdownTheme.h2),
            ("^# .+$",    MarkdownTheme.h1),
        ]
        for (pattern, font) in headerPatterns {
            applyRegex(pattern, to: text, storage: storage, options: [.anchorsMatchLines]) { range in
                storage.addAttributes([.font: font], range: range)
                if let hashEnd = (storage.string as NSString).substring(with: range).range(of: "^#{1,6} ", options: .regularExpression),
                   let sub = Range(range, in: storage.string) {
                    let nsHashRange = NSRange(hashEnd, in: storage.string.substring(with: sub))
                    let absRange = NSRange(location: range.location + nsHashRange.location, length: nsHashRange.length)
                    storage.addAttribute(.foregroundColor, value: MarkdownTheme.dimColor, range: absRange)
                }
            }
        }

        applyRegex("\\*\\*(.+?)\\*\\*", to: text, storage: storage) { range in
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: range)
            dimDelimiters(storage: storage, outerRange: range, delimLen: 2)
        }
        applyRegex("__(.+?)__", to: text, storage: storage) { range in
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: range)
            dimDelimiters(storage: storage, outerRange: range, delimLen: 2)
        }
        applyRegex("\\*(?!\\*)(.+?)(?<!\\*)\\*", to: text, storage: storage) { range in
            let desc = MarkdownTheme.body.fontDescriptor.withSymbolicTraits(.italic)
            if let f = NSFont(descriptor: desc, size: 15) {
                storage.addAttribute(.font, value: f, range: range)
            }
            dimDelimiters(storage: storage, outerRange: range, delimLen: 1)
        }
        applyRegex("`([^`\\n]+)`", to: text, storage: storage) { range in
            storage.addAttributes([.font: MarkdownTheme.mono, .backgroundColor: MarkdownTheme.codeBackground], range: range)
        }
        applyRegex("```[\\s\\S]*?```", to: text, storage: storage) { range in
            storage.addAttributes([.font: MarkdownTheme.mono, .backgroundColor: MarkdownTheme.codeBackground, .foregroundColor: NSColor.labelColor], range: range)
        }
        applyRegex("^> .+$", to: text, storage: storage, options: [.anchorsMatchLines]) { range in
            storage.addAttribute(.foregroundColor, value: MarkdownTheme.dimColor, range: range)
        }
        applyRegex("\\[\\[[^\\]]+\\]\\]", to: text, storage: storage) { range in
            guard range.length > 4 else { return }
            let inner = (text.substring(with: range) as NSString)
                .substring(with: NSRange(location: 2, length: range.length - 4))
            storage.addAttributes([
                .foregroundColor: MarkdownTheme.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: inner,
            ], range: range)
        }
        applyRegex("\\[[^\\]]+\\]\\([^)]+\\)", to: text, storage: storage) { range in
            storage.addAttribute(.foregroundColor, value: MarkdownTheme.linkColor, range: range)
        }
        applyRegex("^---$", to: text, storage: storage, options: [.anchorsMatchLines]) { range in
            storage.addAttribute(.foregroundColor, value: MarkdownTheme.dimColor, range: range)
        }

        storage.endEditing()
    }

    private func applyRegex(_ pattern: String, to text: NSString, storage: NSTextStorage, options: NSRegularExpression.Options = [], apply: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        regex.enumerateMatches(in: text as String, options: [], range: NSRange(location: 0, length: text.length)) { match, _, _ in
            guard let range = match?.range else { return }
            apply(range)
        }
    }

    private func dimDelimiters(storage: NSTextStorage, outerRange: NSRange, delimLen: Int) {
        guard outerRange.length >= delimLen * 2 else { return }
        storage.addAttribute(.foregroundColor, value: MarkdownTheme.dimColor, range: NSRange(location: outerRange.location, length: delimLen))
        storage.addAttribute(.foregroundColor, value: MarkdownTheme.dimColor, range: NSRange(location: outerRange.location + outerRange.length - delimLen, length: delimLen))
    }
}

private func debugLog(_ msg: String) {
    let line = "[Noted] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: "/tmp/noted_debug.log") {
            if let fh = FileHandle(forWritingAtPath: "/tmp/noted_debug.log") {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: "/tmp/noted_debug.log", contents: data)
        }
    }
}

// MARK: - LinkAwareTextView

class LinkAwareTextView: NSTextView {
    var allFiles: [URL] = []
    var onOpenFile: ((URL) -> Void)?

    private var completionPopover: NSPopover?
    private var completionVC: CompletionViewController?
    private var linkTypingRange: NSRange?
    private var eventMonitor: Any?

    override func keyDown(with event: NSEvent) {
        if let popover = completionPopover, popover.isShown {
            switch event.keyCode {
            case 125: completionVC?.moveSelection(by: 1);    return  // down
            case 126: completionVC?.moveSelection(by: -1);   return  // up
            case 36, 76: completionVC?.selectCurrentItem();  return  // return / numpad enter
            case 53: dismissCompletion();                    return  // escape
            default: break
            }
        }
        super.keyDown(with: event)
    }

    func checkForLinkTrigger(plainText: String? = nil, cursor cursorOverride: Int? = nil) {
        let text = plainText ?? string
        let nsText = text as NSString
        var cursor = cursorOverride ?? selectedRange().location
        guard cursor != NSNotFound else { dismissCompletion(); return }
        cursor = min(max(0, cursor), nsText.length)
        guard cursor > 0 else { dismissCompletion(); return }

        // Some NSTextView edit notifications report cursor after a trailing paragraph newline.
        while cursor > 0 {
            let ch = nsText.character(at: cursor - 1)
            if ch == 10 || ch == 13 { cursor -= 1 } else { break }
        }

        let startOffset = max(0, cursor - 400)
        let searchRange = NSRange(location: startOffset, length: cursor - startOffset)
        let sub = nsText.substring(with: searchRange) as NSString
        let bracketRange = sub.range(of: "[[", options: .backwards)
        if bracketRange.location != NSNotFound {
            let absStart = startOffset + bracketRange.location
            let tokenRange = NSRange(location: absStart, length: cursor - absStart)
            let token = nsText.substring(with: tokenRange)
            guard token.hasPrefix("[[") else { dismissCompletion(); return }
            let query = String(token.dropFirst(2))
            debugLog("query='\(query)' allFiles=\(allFiles.count)")
            // Limit completion to the actively typed token only.
            if !query.contains("]]") && !query.contains("\n") && !query.contains("\r") && query.count <= 120 {
                linkTypingRange = tokenRange
                showCompletion(query: query)
                return
            }
        }
        dismissCompletion()
    }

    private func fuzzyScore(query: String, candidate: String) -> Int? {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = CharacterSet(charactersIn: "-_. ")
        let words = candidate.lowercased().components(separatedBy: separators).filter { !$0.isEmpty }
        let strippedCandidate = words.joined()
        let strippedQuery = q.components(separatedBy: separators).joined()
        guard !strippedQuery.isEmpty else { return 0 }

        var qi = strippedQuery.startIndex
        var score = 0
        var lastMatchIdx: String.Index? = nil

        for ci in strippedCandidate.indices {
            guard qi < strippedQuery.endIndex else { break }
            if strippedCandidate[ci] == strippedQuery[qi] {
                if let last = lastMatchIdx, strippedCandidate.index(after: last) == ci { score += 10 }
                score += 1
                lastMatchIdx = ci
                qi = strippedQuery.index(after: qi)
            }
        }
        guard qi == strippedQuery.endIndex else { return nil }

        // Bonus for word-level matches
        for word in words {
            if word.hasPrefix(strippedQuery) { score += 20 }
            else if word.contains(strippedQuery) { score += 12 }
        }

        // Strongly prefer exact middle-substring matches for fuzzyfinder-like behavior.
        if let range = strippedCandidate.range(of: strippedQuery) {
            let start = strippedCandidate.distance(from: strippedCandidate.startIndex, to: range.lowerBound)
            score += 40
            score += max(0, 8 - start)
        }

        return score
    }

    private func showCompletion(query: String) {
        let filtered: [URL]
        if query.isEmpty {
            filtered = allFiles
        } else {
            filtered = allFiles
                .compactMap { url -> (URL, Int)? in
                    let name = url.deletingPathExtension().lastPathComponent
                    guard let score = fuzzyScore(query: query, candidate: name) else { return nil }
                    return (url, score)
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
        }
        debugLog("filtered=\(filtered.count) for query='\(query)'")
        if filtered.isEmpty { dismissCompletion(); return }

        if completionPopover == nil {
            let vc = CompletionViewController()
            vc.onSelect = { [weak self] url in self?.insertLink(url) }
            completionVC = vc
            let popover = NSPopover()
            popover.contentViewController = vc
            popover.behavior = .applicationDefined
            popover.contentSize = NSSize(width: 280, height: 180)
            completionPopover = popover

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.dismissCompletion()
                return event
            }
        }

        completionVC?.update(files: filtered)
        if completionPopover?.isShown == false {
            guard let rect = rectForCaret() else { return }
            completionPopover?.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        }
    }

    func dismissCompletion() {
        completionPopover?.close()
        completionPopover = nil
        completionVC = nil
        linkTypingRange = nil
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func insertLink(_ url: URL) {
        guard let range = linkTypingRange else { return }
        guard range.location >= 0, range.location + range.length <= (string as NSString).length else {
            dismissCompletion()
            return
        }
        let typed = (string as NSString).substring(with: range)
        // Safety guard: only replace a local wiki-link token, never a broad text span.
        guard typed.hasPrefix("[["), !typed.contains("\n"), range.length <= 120 else {
            dismissCompletion()
            return
        }
        let name = url.deletingPathExtension().lastPathComponent
        let linkText = "[[\(name)]]"
        if shouldChangeText(in: range, replacementString: linkText) {
            replaceCharacters(in: range, with: linkText)
            didChangeText()
        }
        dismissCompletion()
    }

    func handleLinkClick(_ link: Any) -> Bool {
        guard let name = link as? String else { return false }
        if let match = allFiles.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
            onOpenFile?(match)
            return true
        }
        return false
    }

    private func rectForCaret() -> NSRect? {
        let range = selectedRange()
        guard range.location != NSNotFound,
              let layoutManager = layoutManager,
              let container = textContainer else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }
}

// MARK: - Completion popover

class CompletionViewController: NSViewController {
    var onSelect: ((URL) -> Void)?
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var files: [URL] = []

    override func loadView() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.isEditable = false
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = 26
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(selectItem)
        tableView.target = self
        tableView.allowsEmptySelection = false

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        view = scrollView
    }

    func update(files: [URL]) {
        self.files = files
        tableView.reloadData()
        if !files.isEmpty { tableView.selectRowIndexes([0], byExtendingSelection: false) }
    }

    @objc func selectItem() {
        let row = tableView.selectedRow
        guard row >= 0, row < files.count else { return }
        onSelect?(files[row])
    }

    func selectCurrentItem() { selectItem() }

    func moveSelection(by delta: Int) {
        let next = max(0, min(files.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }
}

extension CompletionViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let name = files[row].deletingPathExtension().lastPathComponent
        let cell = NSTextField(labelWithString: name)
        cell.font = .systemFont(ofSize: 13)
        cell.lineBreakMode = .byTruncatingMiddle
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {}
}
