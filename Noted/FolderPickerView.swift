import SwiftUI

struct FolderPickerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Noted")
                    .font(.largeTitle.bold())
                Text("A markdown editor with integrated terminal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: appState.pickFolder) {
                Label("Open Folder…", systemImage: "folder.badge.plus")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
