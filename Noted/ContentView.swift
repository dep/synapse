import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 12) {
                headerBar

                HSplitView {
                    VSplitView {
                        FileTreeView()
                            .padding(3)
                            .frame(minHeight: 260)
                            .notedPanel(radius: 16)

                        RelatedLinksPaneView()
                            .padding(3)
                            .frame(minHeight: 180, idealHeight: 240)
                            .notedPanel(radius: 16)
                    }
                        .frame(minWidth: 220, idealWidth: 280, maxWidth: 420)

                    EditorView()
                        .padding(3)
                        .frame(minWidth: 420)
                        .notedPanel(radius: 16)

                    TerminalPaneView()
                        .padding(3)
                        .frame(minWidth: 280, idealWidth: 340, maxWidth: 620)
                        .notedPanel(radius: 16)
                }
            }
            .padding(12)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Noted")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(NotedTheme.textPrimary)

                    TinyBadge(text: "Markdown workspace")
                }

                Text(appState.rootURL?.path ?? "Open a folder to start writing")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(NotedTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let file = appState.selectedFile {
                HStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(NotedTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(NotedTheme.textPrimary)
                        Text(file.deletingLastPathComponent().lastPathComponent)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(NotedTheme.textMuted)
                    }

                    if appState.isDirty {
                        TinyBadge(text: "Unsaved", color: NotedTheme.success)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
            }

            HStack(spacing: 10) {
                Button(action: appState.goBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(ChromeButtonStyle())
                .disabled(!appState.canGoBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("Go Back (⌘[)")

                Button(action: appState.goForward) {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(ChromeButtonStyle())
                .disabled(!appState.canGoForward)
                .keyboardShortcut("]", modifiers: .command)
                .help("Go Forward (⌘])")

                Button(action: appState.pickFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(ChromeButtonStyle())
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .help("Open Folder (⇧⌘O)")

                if appState.selectedFile != nil {
                    Button(action: { appState.saveCurrentFile(content: appState.fileContent) }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(PrimaryChromeButtonStyle())
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Save (⌘S)")
                    .opacity(appState.isDirty ? 1 : 0.78)
                }
            }
        }
        .padding(12)
        .notedPanel(radius: 18)
    }
}
