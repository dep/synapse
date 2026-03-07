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
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Terminal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let dir = appState.rootURL?.lastPathComponent {
                    Text(dir)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            LocalTerminalView(workingDirectory: appState.rootURL?.path ?? NSHomeDirectory())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
