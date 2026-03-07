import SwiftUI

struct FileNode: Identifiable {
    let id = UUID()
    let url: URL
    var children: [FileNode]?

    var name: String { url.lastPathComponent }
    var isDirectory: Bool { children != nil }
    var isMarkdown: Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }
}

func buildFileTree(at url: URL) -> [FileNode] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    return contents
        .compactMap { childURL -> FileNode? in
            let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let children = buildFileTree(at: childURL)
                return FileNode(url: childURL, children: children)
            } else {
                let ext = childURL.pathExtension.lowercased()
                guard ext == "md" || ext == "markdown" || ext == "txt" else { return nil }
                return FileNode(url: childURL, children: nil)
            }
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
}

struct FileTreeView: View {
    @EnvironmentObject var appState: AppState
    @State private var nodes: [FileNode] = []
    @State private var expandedDirs: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Library")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(NotedTheme.textMuted)

                    Text(appState.rootURL?.lastPathComponent ?? "Files")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(NotedTheme.textPrimary)

                    HStack(spacing: 8) {
                        TinyBadge(text: "\(appState.allFiles.count) notes")
                        if !nodes.isEmpty {
                            TinyBadge(text: "\(nodes.count) root items")
                        }
                    }
                }

                Spacer()

                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(ChromeButtonStyle())
                .help("Refresh")
            }

            Rectangle()
                .fill(NotedTheme.divider)
                .frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(nodes) { node in
                        FileNodeRow(node: node, depth: 0, expandedDirs: $expandedDirs)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: refresh)
        .onChange(of: appState.rootURL) { refresh() }
    }

    private func refresh() {
        guard let root = appState.rootURL else { return }
        nodes = buildFileTree(at: root)
    }
}

struct FileNodeRow: View {
    @EnvironmentObject var appState: AppState
    let node: FileNode
    let depth: Int
    @Binding var expandedDirs: Set<URL>

    private var isExpanded: Bool { expandedDirs.contains(node.url) }
    private var isSelected: Bool { appState.selectedFile == node.url }

    var body: some View {
        Group {
            Button(action: handleTap) {
                HStack(spacing: 4) {
                    Spacer().frame(width: CGFloat(depth) * 16)

                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .frame(width: 10)
                        Image(systemName: isExpanded ? "folder.open" : "folder")
                            .foregroundStyle(NotedTheme.accent)
                    } else {
                        Spacer().frame(width: 10)
                        Image(systemName: node.isMarkdown ? "doc.text" : "doc.plaintext")
                            .foregroundStyle(node.isMarkdown ? NotedTheme.textPrimary : NotedTheme.textSecondary)
                    }

                    Text(node.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : NotedTheme.textPrimary)

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? NotedTheme.accentSoft : NotedTheme.row)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? NotedTheme.accent : NotedTheme.rowBorder, lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)

            if node.isDirectory, isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(node: child, depth: depth + 1, expandedDirs: $expandedDirs)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func handleTap() {
        if node.isDirectory {
            if isExpanded { expandedDirs.remove(node.url) }
            else { expandedDirs.insert(node.url) }
        } else {
            appState.openFile(node.url)
        }
    }
}
