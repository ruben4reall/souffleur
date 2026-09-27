import AppKit
import SouffleurShell

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var updater: SparkleUpdater?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Preferences.register()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ApplicationsFolder.offerToMoveIfNeeded() { return }
        let updater = SparkleUpdater()
        self.updater = updater
        Updates.checker = updater
        let app = Souffleur.shared
        app.start()
        if !Preferences.welcomed, !UserDefaults.standard.bool(forKey: "SouffleurSkipWelcome") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { app.showWelcome() }
        }
        Demo.runIfAsked(app)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Souffleur.shared.willTerminate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { Souffleur.shared.importDocuments(files) }
        urls.filter { !$0.isFileURL }.forEach { Souffleur.shared.open($0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Souffleur.shared.showLibrary() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
