import AppKit

/// Offers, once, to move Souffleur into Applications when it was opened from somewhere else, such as the disk image or
/// Downloads: login items and updates need it to stay in one place.
@MainActor
enum ApplicationsFolder {
    private static let declinedKey = "declinedMoveToApplications"

    /// Returns true when the app is being moved and relaunched, so launching should stop here.
    static func offerToMoveIfNeeded() -> Bool {
        let bundle = Bundle.main.bundleURL
        let path = bundle.path
        let applications = ["/Applications/", NSHomeDirectory() + "/Applications/"]
        // Development builds live in build folders: never offer to move those.
        guard !applications.contains(where: path.hasPrefix), !path.contains("/.build/"), !path.contains("/DerivedData/"),
              !UserDefaults.standard.bool(forKey: declinedKey)
        else { return false }

        let alert = NSAlert()
        alert.messageText = String(localized: "Move Souffleur to the Applications folder?")
        alert.informativeText = String(localized: "Souffleur works best from Applications: it can open at login and update itself there.")
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        alert.icon = NSApp.applicationIconImage
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true, forKey: declinedKey)
            return false
        }
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(bundle.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: bundle, to: destination)
        } catch {
            let failure = NSAlert(error: error)
            failure.runModal()
            return false
        }
        // Open the copy once this process has exited, then quit; the disk image can then be ejected.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", destination.path]
        try? relaunch.run()
        NSApp.terminate(nil)
        return true
    }
}
