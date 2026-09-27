import AppIntents
import SouffleurShell

struct PromptTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Prompt Text"
    static let description = IntentDescription("Opens Souffleur's prompter on a text.")

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        Souffleur.shared.prompt(text: text)
        return .result()
    }
}

struct PromptSelectedIntent: AppIntent {
    static let title: LocalizedStringResource = "Prompt the Selected Script"
    static let description = IntentDescription("Opens Souffleur's prompter on the script selected in the library.")

    @MainActor
    func perform() async throws -> some IntentResult {
        Souffleur.shared.promptSelected()
        return .result()
    }
}

struct TogglePrompterIntent: AppIntent {
    static let title: LocalizedStringResource = "Play or Pause the Prompter"

    @MainActor
    func perform() async throws -> some IntentResult {
        Souffleur.shared.playPause()
        return .result()
    }
}

struct ClosePrompterIntent: AppIntent {
    static let title: LocalizedStringResource = "Close the Prompter"

    @MainActor
    func perform() async throws -> some IntentResult {
        Souffleur.shared.prompter.stop()
        return .result()
    }
}

struct SouffleurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PromptSelectedIntent(), phrases: ["Prompt my script in \(.applicationName)"],
                    shortTitle: "Prompt Script", systemImageName: "play.fill")
        AppShortcut(intent: TogglePrompterIntent(), phrases: ["Play or pause \(.applicationName)"],
                    shortTitle: "Play or Pause", systemImageName: "playpause.fill")
        AppShortcut(intent: ClosePrompterIntent(), phrases: ["Close \(.applicationName)"],
                    shortTitle: "Close Prompter", systemImageName: "xmark")
    }
}
