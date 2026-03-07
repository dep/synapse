import SwiftUI
import SwiftTerm

struct LocalTerminalView: NSViewRepresentable {
    let workingDirectory: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["SHELL"] = "/bin/zsh"
        env["PWD"] = workingDirectory
        let envArray = env.map { "\($0.key)=\($0.value)" }

        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: envArray,
            execName: "zsh"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let escaped = workingDirectory.replacingOccurrences(of: " ", with: "\\ ")
            terminal.send(txt: "cd \(escaped) && CLAUDECODE=null claude --dangerously-skip-permissions\n")
        }
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

struct TerminalPaneView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(NotedTheme.textMuted)

                    HStack(spacing: 10) {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(NotedTheme.accent)
                        Text(appState.rootURL?.lastPathComponent ?? "Shell")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(NotedTheme.textPrimary)
                    }

                    Text(appState.rootURL?.path ?? NSHomeDirectory())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(NotedTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                TinyBadge(text: "Live session")
            }

            Rectangle()
                .fill(NotedTheme.divider)
                .frame(height: 1)

            LocalTerminalView(workingDirectory: appState.rootURL?.path ?? NSHomeDirectory())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NotedTheme.border, lineWidth: 1)
                }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
