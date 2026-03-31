import SwiftUI

/// Banner shown when an update is available. Shows install progress and restart prompt.
struct UpdateBannerView: View {
    let version: String
    @Binding var isPresented: Bool
    var downloadProgress: Double?
    var restartRequired: Bool
    var onInstall: () -> Void
    var onRestart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(SynapseTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                if let progress = downloadProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 200)
                        .tint(SynapseTheme.accent)
                } else {
                    Text(subtitleText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if downloadProgress == nil {
                Button(action: restartRequired ? onRestart : onInstall) {
                    Text(restartRequired ? "Restart" : "Install")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SynapseTheme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            if !restartRequired && downloadProgress == nil {
                Button(action: {
                    withAnimation { isPresented = false }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
        .padding()
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var iconName: String {
        if restartRequired { return "checkmark.circle.fill" }
        if downloadProgress != nil { return "arrow.down.circle.fill" }
        return "arrow.down.circle.fill"
    }

    private var titleText: String {
        if restartRequired { return "Synapse v\(version) installed" }
        if downloadProgress != nil {
            let pct = Int((downloadProgress ?? 0) * 100)
            return "Downloading v\(version)… \(pct)%"
        }
        return "Update available: v\(version)"
    }

    private var subtitleText: String {
        if restartRequired { return "Restart to finish updating" }
        return "Click Install to update automatically"
    }
}

#Preview {
    VStack(spacing: 16) {
        UpdateBannerView(
            version: "1.2.0",
            isPresented: .constant(true),
            downloadProgress: nil,
            restartRequired: false,
            onInstall: {},
            onRestart: {}
        )
        UpdateBannerView(
            version: "1.2.0",
            isPresented: .constant(true),
            downloadProgress: 0.6,
            restartRequired: false,
            onInstall: {},
            onRestart: {}
        )
        UpdateBannerView(
            version: "1.2.0",
            isPresented: .constant(true),
            downloadProgress: nil,
            restartRequired: true,
            onInstall: {},
            onRestart: {}
        )
    }
    .frame(width: 500)
    .preferredColorScheme(.dark)
}
