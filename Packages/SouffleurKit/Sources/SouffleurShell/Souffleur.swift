import AppKit
import Carbon.HIToolbox
import Observation
import ServiceManagement
import SouffleurCore
import SwiftUI

/// The app: the library, the prompter, and every way to control it (shortcuts, clicker keys, the phone remote,
/// links and Shortcuts actions).
@MainActor
@Observable
public final class Souffleur {
    public static let shared = Souffleur()

    public let store: ScriptStore
    public let prompter = PrompterController()
    public let remote = RemoteServer()
    /// Bumped when the remote's status changes, so SwiftUI redraws the Remote settings.
    public private(set) var remoteRevision = 0
    /// Shortcuts another app already holds, as they read ("⌃⌥⌘P").
    public private(set) var takenShortcuts: [String] = []

    @ObservationIgnored private var hotKeys: HotKeys?
    @ObservationIgnored private var mainKeys: [UInt32] = []
    @ObservationIgnored private var clickerKeys: [UInt32] = []
    /// The scroll mode last chosen in the window or in Settings: choosing another applies to the take on screen at
    /// once. A take that falls back on its own (no voice model) keeps its fallback until the next choice.
    @ObservationIgnored private var chosenMode = Preferences.mode
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    /// Set by the first SwiftUI scene, to open windows from outside SwiftUI.
    @ObservationIgnored public var openWindow: ((String) -> Void)?

    private init() {
        Preferences.register()
        store = ScriptStore()
    }

    /// Called once at launch.
    public func start() {
        hotKeys = HotKeys()
        prompter.onChange = { [weak self] in self?.prompterChanged() }
        remote.onCommand = { [weak self] command in self?.perform(command) }
        remote.state = { [weak self] in self?.remoteState() ?? RemoteState(title: "", isRolling: false, progress: 0, wordsPerMinute: 0, line: "", remaining: 0) }
        remote.onStatusChange = { [weak self] in self?.remoteRevision += 1 }
        applyPreferences()
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }
    }

    public func willTerminate() {
        store.flush()
        prompter.stop()
        remote.stop()
    }

    // MARK: Prompting

    /// Opens the prompter on the selected script.
    public func promptSelected() {
        guard let document = store.selected else { return }
        prompt(document)
    }

    public func prompt(_ document: ScriptDocument) {
        store.flush()
        prompter.start(text: document.text, title: document.title)
    }

    public func prompt(text: String, title: String? = nil) {
        let heading = title ?? String(text.split(separator: "\n").first ?? "").trimmingCharacters(in: .whitespaces)
        prompter.start(text: text, title: heading)
    }

    /// Prompts whatever text is on the clipboard.
    public func promptClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        prompt(text: text, title: String(localized: "Clipboard", bundle: .module))
    }

    /// The main shortcut: opens the prompter on the selected script, or plays and pauses it.
    public func playPause() {
        if prompter.isActive { prompter.toggle() } else { promptSelected() }
    }

    public func showOrHide() {
        if prompter.isActive { prompter.stop() } else { promptSelected() }
    }

    public var canPrompt: Bool { !(store.selected.map { Script($0.text).isEmpty } ?? true) }

    // MARK: Library

    /// Adds dropped or opened documents to the library and selects the last one.
    @discardableResult
    public func importDocuments(_ urls: [URL]) -> Bool {
        var imported = false
        for url in urls {
            do {
                let text = try ScriptImporter.text(from: url)
                store.create(text: text)
                imported = true
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
        if imported { showLibrary() }
        return imported
    }

    public func showLibrary() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("library") == true }) {
            window.makeKeyAndOrderFront(nil)
        } else if let openWindow {
            openWindow("library")
        } else if let item = NSApp.mainMenu?.items.first(where: { $0.submenu?.items.contains { $0.title == "Souffleur" } == true })?
            .submenu?.items.first(where: { $0.title == "Souffleur" }), let action = item.action {
            // SwiftUI lists its windows in the Window menu: its item opens the library when nothing else can.
            NSApp.sendAction(action, to: item.target, from: item)
        }
    }

    public func showWelcome() {
        WelcomeWindow.show(app: self)
    }

    // MARK: Links

    /// souffleur://prompt?text=…&title=…, souffleur://toggle, play, pause, stop, faster, slower, restart, library
    public func open(_ url: URL) {
        guard url.scheme == "souffleur" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        switch url.host ?? "" {
        case "prompt":
            if let text = value("text"), !text.isEmpty { prompt(text: text, title: value("title")) } else { promptSelected() }
        case "toggle": playPause()
        case "play": if prompter.isActive { prompter.resume() } else { promptSelected() }
        case "pause": prompter.pause()
        case "stop", "hide": prompter.stop()
        case "faster": prompter.faster()
        case "slower": prompter.slower()
        case "restart": prompter.restart()
        case "clipboard": promptClipboard()
        case "library": showLibrary()
        default: break
        }
    }

    // MARK: Remote

    private func perform(_ command: RemoteCommand) {
        switch command {
        case .toggle: playPause()
        case .faster: prompter.faster()
        case .slower: prompter.slower()
        case .back: prompter.moveLine(-1)
        case .forward: prompter.moveLine(1)
        case .restart: prompter.restart()
        }
    }

    private func remoteState() -> RemoteState {
        let state = prompter.state
        guard prompter.isActive else {
            return RemoteState(title: store.selected?.title ?? "", isRolling: false, progress: 0, wordsPerMinute: 0, line: "", remaining: 0)
        }
        let pace = state.mode == .voice ? (state.measuredPace ?? 0) : state.wordsPerMinute
        return RemoteState(title: state.title, isRolling: state.isRolling, progress: state.progress, wordsPerMinute: pace, line: prompter.currentLine, remaining: state.remaining)
    }

    private func prompterChanged() {
        remote.broadcast()
        updateClickerKeys()
    }

    // MARK: Settings

    private func applyPreferences() {
        if Preferences.hotKeys, mainKeys.isEmpty {
            let chord = HotKeys.chord
            let result = hotKeys?.register([
                .init(key: kVK_ANSI_P, modifiers: chord, label: "⌃⌥⌘P") { [weak self] in self?.playPause() },
                .init(key: kVK_UpArrow, modifiers: chord, label: "⌃⌥⌘↑") { [weak self] in self?.prompter.faster() },
                .init(key: kVK_DownArrow, modifiers: chord, label: "⌃⌥⌘↓") { [weak self] in self?.prompter.slower() },
                .init(key: kVK_LeftArrow, modifiers: chord, label: "⌃⌥⌘←") { [weak self] in self?.prompter.moveLine(-1) },
                .init(key: kVK_RightArrow, modifiers: chord, label: "⌃⌥⌘→") { [weak self] in self?.prompter.moveLine(1) },
                .init(key: kVK_ANSI_H, modifiers: chord, label: "⌃⌥⌘H") { [weak self] in self?.showOrHide() },
                .init(key: kVK_ANSI_R, modifiers: chord, label: "⌃⌥⌘R") { [weak self] in self?.prompter.restart() },
            ])
            mainKeys = result?.ids ?? []
            takenShortcuts = result?.taken ?? []
        } else if !Preferences.hotKeys, !mainKeys.isEmpty {
            hotKeys?.unregister(mainKeys)
            mainKeys = []
            takenShortcuts = []
        }
        updateClickerKeys()
        prompter.paceChanged()
        if Preferences.mode != chosenMode {
            chosenMode = Preferences.mode
            if prompter.isActive { prompter.switchMode(chosenMode) }
        }
        if Preferences.remoteEnabled, !remote.isRunning { remote.start() }
        if !Preferences.remoteEnabled, remote.isRunning { remote.stop() }
        let policy: NSApplication.ActivationPolicy = Preferences.showsDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    /// Page Up and Page Down, which presentation clickers and foot pedals send, move the script, but only while the
    /// prompter is on screen, so they keep working everywhere else the rest of the time.
    private func updateClickerKeys() {
        let wanted = Preferences.clickerKeys && prompter.isActive
        if wanted, clickerKeys.isEmpty {
            clickerKeys = hotKeys?.register([
                .init(key: kVK_PageDown, modifiers: 0, label: "Page Down") { [weak self] in self?.clickerNext() },
                .init(key: kVK_PageUp, modifiers: 0, label: "Page Up") { [weak self] in self?.prompter.moveLine(-1) },
            ]).ids ?? []
        } else if !wanted, !clickerKeys.isEmpty {
            hotKeys?.unregister(clickerKeys)
            clickerKeys = []
        }
    }

    /// A clicker's "next" starts a paused take, and otherwise moves one line on.
    private func clickerNext() {
        switch prompter.state.phase {
        case .paused, .countdown, .finished: prompter.toggle()
        default: prompter.moveLine(1)
        }
    }

    public var opensAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
