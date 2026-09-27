import AppKit
import SouffleurShell
import Sparkle

/// Sparkle reads the update feed on the website and installs EdDSA-signed disk images from GitHub Releases. Debug
/// builds never start it, so a development copy is never replaced by a release.
@MainActor
final class SparkleUpdater: NSObject, UpdateChecking {
    private let reminders: UpdateReminders
    private let controller: SPUStandardUpdaterController

    override init() {
        let reminders = UpdateReminders()
        self.reminders = reminders
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: reminders)
        super.init()
        #if !DEBUG
        controller.startUpdater()
        #endif
    }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}

/// Sparkle's gentle reminders: a version found by a scheduled check waits for a quiet moment instead of an alert that
/// would take focus in the middle of a take.
@MainActor
private final class UpdateReminders: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    private(set) var pendingVersion: String?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !state.userInitiated else { return }
        pendingVersion = update.displayVersionString
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingVersion = nil
    }
}

