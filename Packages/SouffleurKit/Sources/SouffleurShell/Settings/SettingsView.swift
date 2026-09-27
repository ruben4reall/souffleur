import AppKit
import Speech
import SouffleurCore
import SwiftUI

/// Settings, one pane per subject, in the style of System Settings.
public struct SettingsView: View {
    let app: Souffleur

    public init(app: Souffleur) { self.app = app }

    public var body: some View {
        TabView {
            GeneralPane(app: app).frame(height: 400)
                .tabItem { Label(String(localized: "General", bundle: .module), systemImage: "gearshape") }
            PrompterPane(app: app).frame(height: 660)
                .tabItem { Label(String(localized: "Prompter", bundle: .module), systemImage: "text.alignleft") }
            VoicePane().frame(height: 500)
                .tabItem { Label(String(localized: "Voice", bundle: .module), systemImage: "waveform") }
            ControlsPane(app: app).frame(height: 620)
                .tabItem { Label(String(localized: "Controls", bundle: .module), systemImage: "command") }
            AboutPane().frame(height: 360)
                .tabItem { Label(String(localized: "About", bundle: .module), systemImage: "info.circle") }
        }
        .frame(width: 580)
        .tint(Theme.accent)
    }
}

private struct GeneralPane: View {
    let app: Souffleur
    @AppStorage(Preferences.Key.showsDockIcon) private var showsDockIcon = true
    @AppStorage(Preferences.Key.showsMenuBarItem) private var showsMenuBarItem = true
    @State private var opensAtLogin = false
    @State private var checksForUpdates = Updates.checker?.automaticallyChecksForUpdates ?? true

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Open at login", bundle: .module), isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, value in if app.opensAtLogin != value { app.opensAtLogin = value } }
                Toggle(String(localized: "Show in the Dock", bundle: .module), isOn: $showsDockIcon)
                Toggle(String(localized: "Show in the menu bar", bundle: .module), isOn: $showsMenuBarItem)
            }
            Section {
                LabeledContent(String(localized: "Scripts", bundle: .module)) {
                    Button(String(localized: "Show in Finder", bundle: .module)) { app.store.revealInFinder() }
                }
            } footer: {
                Text("Each script is a plain Markdown file on your Mac.", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            if let checker = Updates.checker {
                Section {
                    Toggle(String(localized: "Check for updates automatically", bundle: .module), isOn: $checksForUpdates)
                        .onChange(of: checksForUpdates) { _, value in checker.automaticallyChecksForUpdates = value }
                    LabeledContent(String(localized: "Version \(Self.version)", bundle: .module)) {
                        Button(String(localized: "Check Now", bundle: .module)) { checker.checkForUpdates() }
                            .disabled(!checker.canCheckForUpdates)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { opensAtLogin = app.opensAtLogin }
    }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
}

private struct PrompterPane: View {
    let app: Souffleur
    @AppStorage(Preferences.Key.placement) private var placement = PrompterPlacement.notch.rawValue
    @AppStorage(Preferences.Key.notchWidth) private var notchWidth = 380.0
    @AppStorage(Preferences.Key.notchLines) private var notchLines = 3.0
    @AppStorage(Preferences.Key.floatingWidth) private var floatingWidth = 520.0
    @AppStorage(Preferences.Key.floatingHeight) private var floatingHeight = 200.0
    @AppStorage(Preferences.Key.fullScreenDisplay) private var fullScreenDisplay = ""
    @AppStorage(Preferences.Key.fullScreenFontSize) private var fullScreenFontSize = 64.0
    @AppStorage(Preferences.Key.font) private var font = PrompterFont.system.rawValue
    @AppStorage(Preferences.Key.fontSize) private var fontSize = 19.0
    @AppStorage(Preferences.Key.lineSpacing) private var lineSpacing = 1.28
    @AppStorage(Preferences.Key.alignment) private var alignment = "center"
    @AppStorage(Preferences.Key.theme) private var theme = PrompterTheme.night.rawValue
    @AppStorage(Preferences.Key.dimsReadWords) private var dimsReadWords = true
    @AppStorage(Preferences.Key.mirror) private var mirror = MirrorMode.none.rawValue
    @AppStorage(Preferences.Key.countdown) private var countdown = true
    @AppStorage(Preferences.Key.showsTimer) private var showsTimer = true
    @AppStorage(Preferences.Key.hiddenFromCapture) private var hiddenFromCapture = true

    var body: some View {
        Form {
            Section(String(localized: "Place", bundle: .module)) {
                Picker(String(localized: "Show the prompter", bundle: .module), selection: $placement) {
                    ForEach(PrompterPlacement.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                switch PrompterPlacement(rawValue: placement) ?? .notch {
                case .notch:
                    slider(String(localized: "Width", bundle: .module), value: $notchWidth, in: 340...760, step: 10, unit: "pt")
                    Stepper(value: $notchLines, in: 2...8) {
                        LabeledContent(String(localized: "Lines", bundle: .module), value: "\(Int(notchLines))")
                    }
                case .floating:
                    slider(String(localized: "Width", bundle: .module), value: $floatingWidth, in: 380...1200, step: 10, unit: "pt")
                    slider(String(localized: "Height", bundle: .module), value: $floatingHeight, in: 140...700, step: 10, unit: "pt")
                case .fullScreen:
                    Picker(String(localized: "Display", bundle: .module), selection: $fullScreenDisplay) {
                        Text("Automatic", bundle: .module).tag("")
                        ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                    }
                    slider(String(localized: "Text size", bundle: .module), value: $fullScreenFontSize, in: 36...140, step: 2, unit: "pt")
                    Picker(String(localized: "Mirror", bundle: .module), selection: $mirror) {
                        ForEach(MirrorMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            Section(String(localized: "Text", bundle: .module)) {
                Picker(String(localized: "Font", bundle: .module), selection: $font) {
                    ForEach(PrompterFont.allCases) { Text($0.title).tag($0.rawValue) }
                }
                slider(String(localized: "Size", bundle: .module), value: $fontSize, in: 14...48, step: 1, unit: "pt")
                slider(String(localized: "Line spacing", bundle: .module), value: $lineSpacing, in: 1.0...1.8, step: 0.05, unit: "×")
                Picker(String(localized: "Alignment", bundle: .module), selection: $alignment) {
                    Text("Centered", bundle: .module).tag("center")
                    Text("Left", bundle: .module).tag("left")
                }
                .pickerStyle(.segmented)
                Picker(String(localized: "Colors", bundle: .module), selection: $theme) {
                    ForEach(PrompterTheme.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Toggle(String(localized: "Dim the words already read", bundle: .module), isOn: $dimsReadWords)
                if PrompterPlacement(rawValue: placement) != .fullScreen {
                    Picker(String(localized: "Mirror", bundle: .module), selection: $mirror) {
                        ForEach(MirrorMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            Section(String(localized: "Take", bundle: .module)) {
                Toggle(String(localized: "Count down from 3 before rolling", bundle: .module), isOn: $countdown)
                Toggle(String(localized: "Show the timer", bundle: .module), isOn: $showsTimer)
            }
            Section {
                Toggle(String(localized: "Hide from screen sharing and recordings", bundle: .module), isOn: $hiddenFromCapture)
            } footer: {
                Text("Apps that respect macOS's capture protection won't see the prompter. Since macOS 15, some screen sharing and recording apps capture it anyway: share a window rather than your whole screen to be sure.", bundle: .module)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                HStack {
                    Spacer()
                    Button(String(localized: "Try It", bundle: .module)) {
                        app.prompt(text: ScriptStore.welcomeScript, title: "Souffleur")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step)
                Text(step < 1 ? String(format: "%.2f%@", value.wrappedValue, unit) : "\(Int(value.wrappedValue)) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .trailing)
            }
        }
    }
}

private struct VoicePane: View {
    @AppStorage(Preferences.Key.mode) private var mode = ScrollMode.voice.rawValue
    @AppStorage(Preferences.Key.voiceLanguage) private var language = "auto"
    @AppStorage(Preferences.Key.wordsPerMinute) private var pace = Pace.conversational
    @State private var locales: [Locale] = []

    var body: some View {
        Form {
            Section(String(localized: "Scrolling", bundle: .module)) {
                ForEach(ScrollMode.allCases) { option in
                    Button { mode = option.rawValue } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(mode == option.rawValue ? Theme.accent : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).font(.system(size: 13, weight: .semibold))
                                Text(option.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if mode == option.rawValue {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.bold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                Picker(String(localized: "Language", bundle: .module), selection: $language) {
                    Text("Same as the script", bundle: .module).tag("auto")
                    Divider()
                    ForEach(locales, id: \.identifier) { locale in
                        Text(Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier).tag(locale.identifier)
                    }
                }
                LabeledContent(String(localized: "Pace", bundle: .module)) {
                    HStack {
                        Slider(value: $pace, in: Preferences.minimumPace...Preferences.maximumPace, step: 5)
                        Text("\(Int(pace)) wpm").monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
            } footer: {
                Text("Recognition runs on your Mac. Souffleur gives the recognizer the words of your script, so names and jargon are heard right. Voice Pace and Auto Scroll use the pace.", bundle: .module)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            locales = SFSpeechRecognizer.supportedLocales().sorted {
                (Locale.current.localizedString(forIdentifier: $0.identifier) ?? "") < (Locale.current.localizedString(forIdentifier: $1.identifier) ?? "")
            }
        }
    }
}

private struct ControlsPane: View {
    let app: Souffleur
    @AppStorage(Preferences.Key.hotKeys) private var hotKeys = true
    @AppStorage(Preferences.Key.clickerKeys) private var clickerKeys = true
    @AppStorage(Preferences.Key.remoteEnabled) private var remoteEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Keyboard shortcuts in every app", bundle: .module), isOn: $hotKeys)
                if hotKeys, !app.takenShortcuts.isEmpty {
                    Label {
                        Text("Another app already uses \(app.takenShortcuts.formatted(.list(type: .and))). Quit it or change its shortcut, then turn this off and on.", bundle: .module)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    }
                    .font(.system(size: 12))
                }
                if hotKeys {
                    shortcut("⌃⌥⌘P", String(localized: "Prompt the selected script, play or pause", bundle: .module))
                    shortcut("⌃⌥⌘↑ ↓", String(localized: "Faster, slower", bundle: .module))
                    shortcut("⌃⌥⌘← →", String(localized: "Back or forward a line", bundle: .module))
                    shortcut("⌃⌥⌘R", String(localized: "Restart", bundle: .module))
                    shortcut("⌃⌥⌘H", String(localized: "Show or hide the prompter", bundle: .module))
                }
            }
            Section {
                Toggle(String(localized: "Presentation remotes and foot pedals", bundle: .module), isOn: $clickerKeys)
            } footer: {
                Text("While the prompter is open, Page Down moves on a line (or starts a paused take) and Page Up goes back. The rest of the time these keys work as usual.", bundle: .module)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Toggle(String(localized: "Phone remote", bundle: .module), isOn: $remoteEnabled)
                if remoteEnabled {
                    RemoteCard(app: app)
                }
            } footer: {
                Text("Your phone must be on the same network. Only a phone that scanned this code can control the prompter.", bundle: .module)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func shortcut(_ keys: String, _ action: String) -> some View {
        LabeledContent(action) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))
        }
    }
}

private struct RemoteCard: View {
    let app: Souffleur

    var body: some View {
        let _ = app.remoteRevision
        HStack(alignment: .center, spacing: 18) {
            if let address = app.remote.address, let image = QRCode.image(for: address.absoluteString, size: 150) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 132, height: 132)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scan with your phone's camera", bundle: .module).font(.system(size: 13, weight: .semibold))
                    Text(address.absoluteString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(app.remote.connectedCount == 0 ? String(localized: "No phone connected", bundle: .module) : String(localized: "\(app.remote.connectedCount) connected", bundle: .module))
                        .font(.system(size: 12))
                        .foregroundStyle(app.remote.connectedCount == 0 ? Color.secondary : Theme.accent)
                    Button(String(localized: "New Pairing Code", bundle: .module)) {
                        Preferences.renewRemoteToken()
                        app.remote.stop()
                        app.remote.start()
                    }
                }
            } else {
                ProgressView().controlSize(.small)
                Text("Starting the remote…", bundle: .module).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Souffleur").font(.system(size: 22, weight: .bold))
            Text("Your lines, right under the camera.", bundle: .module).foregroundStyle(.secondary)
            Text("Version \(GeneralPane.version)", bundle: .module).font(.caption).foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                Link(String(localized: "Website", bundle: .module), destination: URL(string: "https://getsouffleur.vercel.app")!)
                Link(String(localized: "Source Code", bundle: .module), destination: URL(string: "https://github.com/ruben4reall/souffleur")!)
                Link(String(localized: "Report an Issue", bundle: .module), destination: URL(string: "https://github.com/ruben4reall/souffleur/issues")!)
            }
            .padding(.top, 6)
            Text("Free and open source under the MIT License. No account, no analytics: your scripts and your voice stay on your Mac.", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
