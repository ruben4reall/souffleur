import SouffleurShell
import SwiftUI

@main
struct SouffleurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(Preferences.Key.showsMenuBarItem) private var showsMenuBarItem = true

    var body: some Scene {
        Window("Souffleur", id: "library") {
            LibraryView(app: .shared)
                .frame(minWidth: 720, minHeight: 440)
        }
        .defaultSize(width: 1040, height: 680)
        .commands { SouffleurCommands(app: .shared) }

        Settings {
            SettingsView(app: .shared)
        }

        MenuBarExtra(isInserted: $showsMenuBarItem) {
            MenuBarMenu(app: .shared)
        } label: {
            MenuBarLabel(app: .shared)
        }
    }
}
