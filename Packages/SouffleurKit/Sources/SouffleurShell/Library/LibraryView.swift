import AppKit
import SouffleurCore
import SwiftUI
import UniformTypeIdentifiers

/// The main window: the scripts on the left, the one being written on the right with its play button, and the speed
/// card below it.
public struct LibraryView: View {
    @Bindable var store: ScriptStore
    let app: Souffleur
    @State private var search = ""
    @State private var isTargeted = false
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Preferences.Key.mode) private var mode = ScrollMode.pace.rawValue
    @AppStorage(Preferences.Key.placement) private var placement = PrompterPlacement.notch.rawValue
    @AppStorage(Preferences.Key.wordsPerMinute) private var pace = Pace.conversational
    @AppStorage(Preferences.Key.lastSummary) private var lastSummary = ""

    public init(app: Souffleur) {
        self.app = app
        store = app.store
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .searchable(text: $search, placement: .sidebar, prompt: Text("Search", bundle: .module))
        .dropDestination(for: URL.self) { urls, _ in
            app.importDocuments(urls)
        } isTargeted: { isTargeted = $0 }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            app.openWindow = { id in openWindow(id: id) }
        }
    }

    // MARK: Sidebar

    private var filtered: [ScriptDocument] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.documents }
        return store.documents.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    private var sidebar: some View {
        List(selection: $store.selection) {
            ForEach(filtered) { document in
                ScriptRow(document: document)
                    .tag(document.id)
                    .contextMenu {
                        Button(String(localized: "Prompt", bundle: .module)) { app.prompt(document) }
                        Button(String(localized: "Duplicate", bundle: .module)) { store.duplicate(document.id) }
                        Divider()
                        Button(String(localized: "Move to Trash", bundle: .module), role: .destructive) { store.delete(document.id) }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button { store.create() } label: {
                    Label(String(localized: "New Script", bundle: .module), systemImage: "square.and.pencil")
                }
                .help(String(localized: "New Script (⌘N)", bundle: .module))
            }
        }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let document = store.selected {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ScriptEditor(documentID: document.id, text: Binding(
                        get: { store.document(document.id)?.text ?? "" },
                        set: { store.update(document.id, text: $0) }
                    ))
                    PlayButton(app: app)
                        .padding(18)
                }
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
                SpeedPanel(document: document, pace: $pace, mode: $mode, lastSummary: lastSummary)
            }
            .padding(14)
            .navigationTitle(document.title)
            .toolbar { promptToolbar }
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Script", bundle: .module), systemImage: "text.alignleft")
            } description: {
                Text("Write a new script, or drop a text file, a Word document, a PDF or a presentation here.", bundle: .module)
            } actions: {
                Button(String(localized: "New Script", bundle: .module)) { store.create() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
    }

    @ToolbarContentBuilder private var promptToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker(String(localized: "Scrolling", bundle: .module), selection: $mode) {
                    ForEach(ScrollMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                let current = ScrollMode(rawValue: mode) ?? .auto
                Label(current.title, systemImage: current.symbol)
                    .labelStyle(.titleAndIcon)
            }
            .help(String(localized: "How the script moves", bundle: .module))

            Menu {
                Picker(String(localized: "Place", bundle: .module), selection: $placement) {
                    ForEach(PrompterPlacement.allCases) { place in
                        Text(place.title).tag(place.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label((PrompterPlacement(rawValue: placement) ?? .notch).title, systemImage: placementSymbol)
                    .labelStyle(.titleAndIcon)
            }
            .help(String(localized: "Where the prompter appears", bundle: .module))

        }
    }

    private var placementSymbol: String {
        switch PrompterPlacement(rawValue: placement) ?? .notch {
        case .notch: "macbook"
        case .floating: "rectangle.on.rectangle"
        case .fullScreen: "rectangle.inset.filled"
        }
    }

}

private struct ScriptRow: View {
    let document: ScriptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(document.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if !document.preview.isEmpty {
                Text(document.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(document.modified, format: .relative(presentation: .named))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }
}

/// The app's menu commands for scripts and the prompter.
public struct SouffleurCommands: Commands {
    let app: Souffleur

    public init(app: Souffleur) { self.app = app }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "New Script", bundle: .module)) {
                app.showLibrary()
                app.store.create()
            }
            .keyboardShortcut("n")
            Button(String(localized: "Import…", bundle: .module)) { importDocuments() }
                .keyboardShortcut("o")
        }
        CommandMenu(String(localized: "Prompter", bundle: .module)) {
            Button(String(localized: "Prompt Selected Script", bundle: .module)) { app.promptSelected() }
                .keyboardShortcut(.return, modifiers: .command)
            Button(String(localized: "Prompt Clipboard", bundle: .module)) { app.promptClipboard() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            Divider()
            Button(String(localized: "Play or Pause", bundle: .module)) { app.playPause() }
            Button(String(localized: "Restart", bundle: .module)) { app.prompter.restart() }
            Button(String(localized: "Close Prompter", bundle: .module)) { app.prompter.stop() }
                .keyboardShortcut(".", modifiers: .command)
        }
        CommandGroup(replacing: .help) {
            Button(String(localized: "Welcome to Souffleur", bundle: .module)) { app.showWelcome() }
            Link(String(localized: "Souffleur Website", bundle: .module), destination: URL(string: "https://getsouffleur.vercel.app")!)
            Link(String(localized: "Report an Issue", bundle: .module), destination: URL(string: "https://github.com/ruben4reall/souffleur/issues")!)
        }
    }

    @MainActor private func importDocuments() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ScriptImporter.contentTypes
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Import", bundle: .module)
        guard panel.runModal() == .OK else { return }
        app.importDocuments(panel.urls)
    }
}
