import AppKit
import SwiftUI

/// The menu bar item: prompt, control the take, open the library.
public struct MenuBarMenu: View {
    let app: Souffleur
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    public init(app: Souffleur) { self.app = app }

    public var body: some View {
        let state = app.prompter.state
        if app.prompter.isActive {
            Button(state.isRolling ? String(localized: "Pause", bundle: .module) : String(localized: "Play", bundle: .module)) { app.prompter.toggle() }
            Button(String(localized: "Restart", bundle: .module)) { app.prompter.restart() }
            Button(String(localized: "Close Prompter", bundle: .module)) { app.prompter.stop() }
        } else {
            Button(app.store.selected.map { String(localized: "Prompt “\($0.title)”", bundle: .module) } ?? String(localized: "Prompt", bundle: .module)) {
                app.promptSelected()
            }
            .disabled(!app.canPrompt)
            Button(String(localized: "Prompt Clipboard", bundle: .module)) { app.promptClipboard() }
        }
        Divider()
        Button(String(localized: "Open Library", bundle: .module)) {
            app.openWindow = { id in openWindow(id: id) }
            app.showLibrary()
        }
        Button(String(localized: "Settings…", bundle: .module)) {
            NSApp.activate()
            openSettings()
        }
        if let checker = Updates.checker {
            Button(String(localized: "Check for Updates…", bundle: .module)) { checker.checkForUpdates() }
        }
        Divider()
        Button(String(localized: "Quit Souffleur", bundle: .module)) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// The menu bar icon. It is drawn at launch, so it also hands the app the action that opens SwiftUI windows.
public struct MenuBarLabel: View {
    let app: Souffleur
    @Environment(\.openWindow) private var openWindow

    public init(app: Souffleur) { self.app = app }

    public var body: some View {
        Image(systemName: app.prompter.state.isRolling ? "rectangle.topthird.inset.filled" : "rectangle.topthird.inset.filled")
            .onAppear { app.openWindow = { id in openWindow(id: id) } }
    }
}
