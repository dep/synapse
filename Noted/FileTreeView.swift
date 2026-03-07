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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(appState.rootURL?.lastPathComponent ?? "Files")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(nodes) { node in
                        FileNodeRow(node: node, depth: 0, expandedDirs: $expandedDirs)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(.background)
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
                            .foregroundStyle(.blue)
                    } else {
                        Spacer().frame(width: 10)
                        Image(systemName: node.isMarkdown ? "doc.text" : "doc.plaintext")
                            .foregroundStyle(node.isMarkdown ? .primary : .secondary)
                    }

                    Text(node.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.accentColor : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            if node.isDirectory, isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(node: child, depth: depth + 1, expandedDirs: $expandedDirs)
                }
            }
        }
        .padding(.horizontal, 4)
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
