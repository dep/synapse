import SwiftUI
import AppKit

enum NotedTheme {
    static let canvasTop = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let canvasBottom = Color(red: 0.04, green: 0.05, blue: 0.07)
    static let glowA = Color(red: 0.12, green: 0.39, blue: 0.78)
    static let glowB = Color(red: 0.04, green: 0.73, blue: 0.68)
    static let panel = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let panelElevated = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let editorShell = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let row = Color.white.opacity(0.03)
    static let rowBorder = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.05)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.64)
    static let textMuted = Color.white.opacity(0.42)
    static let accent = Color(red: 0.28, green: 0.66, blue: 0.98)
    static let accentSoft = Color(red: 0.20, green: 0.48, blue: 0.89)
    static let accentGlow = Color(red: 0.16, green: 0.78, blue: 0.74)
    static let success = Color(red: 0.37, green: 0.83, blue: 0.60)

    static let editorBackground = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1)
    static let editorForeground = NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.98, alpha: 1)
    static let editorMuted = NSColor(calibratedRed: 0.56, green: 0.62, blue: 0.72, alpha: 1)
    static let editorCodeBackground = NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.22, alpha: 1)
    static let editorSelection = NSColor(calibratedRed: 0.20, green: 0.44, blue: 0.76, alpha: 0.45)
    static let editorLink = NSColor(calibratedRed: 0.47, green: 0.77, blue: 1.00, alpha: 1)
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [NotedTheme.canvasTop, NotedTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(NotedTheme.glowA.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -320, y: -220)

            Circle()
                .fill(NotedTheme.glowB.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 360, y: 260)

            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.clear, Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct PanelSurface: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NotedTheme.panelElevated, NotedTheme.panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(NotedTheme.border, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 14)
            }
    }
}

extension View {
    func notedPanel(radius: CGFloat = 16) -> some View {
        modifier(PanelSurface(radius: radius))
    }
}

struct ChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(NotedTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.05))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
    }
}

struct PrimaryChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NotedTheme.accent, NotedTheme.accentGlow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: NotedTheme.accent.opacity(0.18), radius: 8, x: 0, y: 4)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            }
    }
}

struct TinyBadge: View {
    let text: String
    var color: Color = NotedTheme.textMuted

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}
