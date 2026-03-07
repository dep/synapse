import SwiftUI

@main
struct NotedApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.rootURL == nil {
                FolderPickerView()
                    .environmentObject(appState)
                    .frame(width: 480, height: 280)
            } else {
                ContentView()
                    .environmentObject(appState)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
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
