import SwiftUI

@main
struct NotedApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.rootURL == nil {
                FolderPickerView()
                    .environmentObject(appState)
                    .tint(NotedTheme.accent)
                    .preferredColorScheme(.dark)
                    .frame(minWidth: 560, minHeight: 420)
            } else {
                ContentView()
                    .environmentObject(appState)
                    .tint(NotedTheme.accent)
                    .preferredColorScheme(.dark)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .defaultSize(width: 1320, height: 820)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    appState.pickFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
