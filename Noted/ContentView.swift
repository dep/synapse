import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            FileTreeView()
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 400)

            EditorView()
                .frame(minWidth: 300)

            TerminalPaneView()
                .frame(minWidth: 220, idealWidth: 320, maxWidth: 600)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: appState.pickFolder) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open Folder (⇧⌘O)")
            }
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 0) {
                    Button(action: appState.goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!appState.canGoBack)
                    .help("Go Back (⌘[)")

                    Button(action: appState.goForward) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!appState.canGoForward)
                    .help("Go Forward (⌘])")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if let file = appState.selectedFile {
                    Text(file.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if appState.isDirty {
                    Button(action: { appState.saveCurrentFile(content: appState.fileContent) }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save (⌘S)")
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
        .background {
            Group {
                Button("") { appState.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .hidden()
                Button("") { appState.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .hidden()
            }
        }
    }
}
