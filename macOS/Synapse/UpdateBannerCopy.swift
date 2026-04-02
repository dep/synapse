import Foundation

/// User-visible strings for the in-app update banner (kept separate from SwiftUI for unit testing).
enum UpdateBannerCopy {
    static func iconName(downloadProgress: Double?, restartRequired: Bool) -> String {
        if restartRequired { return "checkmark.circle.fill" }
        if downloadProgress != nil { return "arrow.down.circle.fill" }
        return "arrow.down.circle.fill"
    }

    static func title(version: String, downloadProgress: Double?, restartRequired: Bool) -> String {
        if restartRequired { return "Synapse v\(version) installed" }
        if let progress = downloadProgress {
            let pct = Int(progress * 100)
            return "Downloading v\(version)… \(pct)%"
        }
        return "Update available: v\(version)"
    }

    static func subtitle(downloadProgress: Double?, restartRequired: Bool) -> String {
        if restartRequired { return "Restart to finish updating" }
        if downloadProgress != nil { return "" }
        return "Click Install to update automatically"
    }
}
