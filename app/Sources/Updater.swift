import AppKit

// Checks GitHub for a newer release of Snippet Menu and installs it in place.
final class Updater {
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/2819-dev/Work-Universe/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/2819-dev/Work-Universe/releases/latest")!
    private static let assetName = "Snippet-Menu.zip"
    private static let checkInterval: TimeInterval = 6 * 60 * 60

    private let model: PanelModel
    private var available: (version: String, url: URL)?
    private var timer: Timer?

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    init(model: PanelModel) {
        self.model = model
        model.startUpdate = { [weak self] in self?.install() }
        model.checkForUpdates = { [weak self] in self?.check(userInitiated: true) }
    }

    func start() {
        check(userInitiated: false)
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.check(userInitiated: false)
        }
    }

    // MARK: Checking

    func check(userInitiated: Bool) {
        if model.update == .installing { return }
        var request = URLRequest(url: Self.latestReleaseAPI, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            let release = ok ? data.flatMap(Self.parseRelease) : nil
            DispatchQueue.main.async { self.finishCheck(release, reachable: ok, userInitiated: userInitiated) }
        }.resume()
    }

    private static func parseRelease(_ data: Data) -> (version: String, url: URL)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let asset = assets.first(where: { ($0["name"] as? String) == assetName }),
              let link = asset["browser_download_url"] as? String,
              let url = URL(string: link) else { return nil }
        return (tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url)
    }

    private func finishCheck(_ release: (version: String, url: URL)?, reachable: Bool, userInitiated: Bool) {
        if model.update == .installing { return }
        if let release, AppVersion.isNewer(release.version, than: Self.currentVersion) {
            available = release
            model.update = .available(version: release.version)
            return
        }
        guard userInitiated else { return }
        let alert = NSAlert()
        if reachable {
            alert.messageText = "You're up to date"
            alert.informativeText = "Snippet Menu \(Self.currentVersion) is the latest version."
        } else {
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = "Make sure you're connected to the internet, then try again."
            alert.alertStyle = .warning
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: Installing

    private func install() {
        guard let available else { return }
        let appURL = Bundle.main.bundleURL
        let folder = appURL.deletingLastPathComponent()
        guard appURL.pathExtension == "app",
              !appURL.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: folder.path) else {
            model.update = .failed("Snippet Menu can only update itself when it's in your Applications folder. Move it there, or download the update from the website.")
            return
        }

        model.update = .installing
        URLSession.shared.downloadTask(with: available.url) { downloaded, response, _ in
            do {
                guard let downloaded, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw UpdateError.download
                }
                let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                       appropriateFor: appURL, create: true)
                let zip = work.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: downloaded, to: zip)
                let unzipped = work.appendingPathComponent("unzipped")
                try Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, unzipped.path])
                guard let newApp = Self.findApp(in: unzipped),
                      Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                    throw UpdateError.contents
                }
                try? Self.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
                try Self.run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])
                DispatchQueue.main.async { self.replaceAndRelaunch(appURL: appURL, with: newApp) }
            } catch {
                DispatchQueue.main.async {
                    self.model.update = .failed("The update couldn't be downloaded. Check your internet connection and try again.")
                }
            }
        }.resume()
    }

    private func replaceAndRelaunch(appURL: URL, with newApp: URL) {
        do {
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
        } catch {
            model.update = .failed("The update couldn't be installed. Please try again, or download it from the website.")
            return
        }
        // Reopen the updated app a moment after this one quits.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", appURL.path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private static func findApp(in folder: URL) -> URL? {
        guard let items = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in items where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { throw UpdateError.tool(tool) }
    }

    private enum UpdateError: Error {
        case download, contents, tool(String)
    }
}
