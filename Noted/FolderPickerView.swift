import SwiftUI

struct FolderPickerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(NotedTheme.accent.opacity(0.14))
                            .frame(width: 92, height: 92)
                            .blur(radius: 8)

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 88, height: 88)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }

                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(NotedTheme.textPrimary)
                    }

                    VStack(spacing: 10) {
                        Text("Noted")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(NotedTheme.textPrimary)

                        Text("A sleek markdown workspace with a focused editor, polished navigation, and a built-in terminal.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(NotedTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 360)
                    }

                    HStack(spacing: 8) {
                        TinyBadge(text: "Dark canvas")
                        TinyBadge(text: "Live markdown")
                        TinyBadge(text: "Terminal ready")
                    }

                    Button(action: appState.pickFolder) {
                        Label("Open Folder…", systemImage: "folder.badge.plus")
                            .frame(width: 210)
                    }
                    .buttonStyle(PrimaryChromeButtonStyle())
                    .keyboardShortcut(.defaultAction)

                    Text("Choose a folder of notes to load your workspace.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(NotedTheme.textMuted)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 460)
                .notedPanel(radius: 18)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
