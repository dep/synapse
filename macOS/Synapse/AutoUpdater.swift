import Foundation
import AppKit

/// AutoUpdater checks GitHub Releases for updates, downloads, installs, and prompts restart.
@MainActor
class AutoUpdater: NSObject, ObservableObject {
    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var downloadProgress: Double? = nil  // nil = not downloading, 0.0-1.0 = progress
    @Published var restartRequired: Bool = false

    private let repoOwner = "dep"
    private let repoName = "synapse"
    private let currentVersion: String

    /// Injected for testing; defaults to the shared session in production.
    var urlSession: URLSession = .shared

    init(urlSession: URLSession = .shared) {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            self.currentVersion = version
        } else {
            self.currentVersion = "1.0"
        }
        self.urlSession = urlSession
    }

    /// Check for updates on app launch. Non-blocking, runs in background.
    func checkForUpdatesOnLaunch() {
        Task {
            await checkForUpdates()
        }
    }

    /// Check GitHub Releases API for the latest version
    private func checkForUpdates() async {
        do {
            guard let latestRelease = try await fetchLatestRelease() else { return }

            let latestVersion = latestRelease.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            self.latestVersion = latestVersion

            if isNewerVersion(latest: latestVersion, current: currentVersion) {
                updateAvailable = true
            }
        } catch {
            print("[AutoUpdater] Update check failed: \(error)")
        }
    }

    /// Download the DMG, mount it, copy the .app to /Applications, unmount, and flag restart needed.
    func downloadAndInstall() {
        Task {
            do {
                guard let release = try await fetchLatestRelease() else { return }
                guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                    print("[AutoUpdater] No DMG asset found in release")
                    return
                }

                guard let downloadURL = URL(string: dmgAsset.browserDownloadUrl) else { return }

                // Download with progress
                downloadProgress = 0.0
                let dmgPath = try await downloadWithProgress(url: downloadURL, totalSize: dmgAsset.size)

                // Mount DMG, copy app, unmount
                let mountPoint = try await mountDMG(at: dmgPath)
                try copyApp(from: mountPoint)
                await unmountDMG(at: mountPoint)

                // Clean up temp file
                try? FileManager.default.removeItem(atPath: dmgPath)

                downloadProgress = nil
                restartRequired = true
            } catch {
                print("[AutoUpdater] Install failed: \(error)")
                downloadProgress = nil
            }
        }
    }

    /// Relaunch the app from /Applications so the new version runs.
    func relaunch() {
        let appPath = "/Applications/Synapse.app"
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: appPath),
            configuration: config
        ) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Private helpers

    private func downloadWithProgress(url: URL, totalSize: Int) async throws -> String {
        let tempPath = NSTemporaryDirectory() + "Synapse-update.dmg"
        let destURL = URL(fileURLWithPath: tempPath)
        try? FileManager.default.removeItem(at: destURL)

        let (asyncBytes, response) = try await urlSession.bytes(from: url)
        let total = (response as? HTTPURLResponse).flatMap {
            Int($0.value(forHTTPHeaderField: "Content-Length") ?? "")
        } ?? totalSize

        var data = Data()
        data.reserveCapacity(total)
        var received = 0

        for try await byte in asyncBytes {
            data.append(byte)
            received += 1
            if received % 65536 == 0 {
                downloadProgress = Double(received) / Double(total)
            }
        }
        downloadProgress = 1.0

        try data.write(to: destURL)
        return tempPath
    }

    private func mountDMG(at path: String) async throws -> String {
        let result = try await runProcess(
            "/usr/bin/hdiutil",
            args: ["attach", path, "-nobrowse", "-noautoopen", "-plist"]
        )

        // Parse mount point from hdiutil plist output
        guard let data = result.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            throw UpdateError.installFailed
        }

        return mountPoint
    }

    private func copyApp(from mountPoint: String) throws {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: mountPoint).appendingPathComponent("Synapse.app")
        let destURL = URL(fileURLWithPath: "/Applications/Synapse.app")

        guard fm.fileExists(atPath: sourceURL.path) else {
            throw UpdateError.installFailed
        }

        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.copyItem(at: sourceURL, to: destURL)
    }

    private func unmountDMG(at mountPoint: String) async {
        _ = try? await runProcess("/usr/bin/hdiutil", args: ["detach", mountPoint, "-quiet"])
    }

    @discardableResult
    private func runProcess(_ executable: String, args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.terminationHandler = { _ in
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Fetch the latest release from GitHub API
    private func fetchLatestRelease() async throws -> GitHubRelease? {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    /// Compare version strings (semantic versioning)
    func isNewerVersion(latest: String, current: String) -> Bool {
        let latestClean = latest.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let currentClean = current.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

        let latestComponents = latestClean.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentClean.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestComponents.count, currentComponents.count) {
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0

            if latestPart > currentPart { return true }
            else if latestPart < currentPart { return false }
        }

        return false
    }
}

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let assets: [GitHubAsset]
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
}

enum UpdateError: Error {
    case downloadFailed
    case installFailed
    case unsupportedFormat
}
