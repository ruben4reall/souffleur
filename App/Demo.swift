import AppKit
import SouffleurShell

/// Launch arguments that put the app in a known state, for screenshots and for working on one screen without a
/// microphone. The reader's own scripts are never shown: the demo reads the welcome script.
///
///   -SouffleurDemo notch|floating|fullScreen   opens the prompter on the welcome script
///   -SouffleurDemoVoice YES                    reads it aloud in voice follow, from a scripted transcript
///   -SouffleurDemoStop <word>                  stops reading at that word, to capture a take in progress
///   -SouffleurDemoHover YES                    shows the controls, as when the pointer rests on the prompter
@MainActor
enum Demo {
    static func runIfAsked(_ app: Souffleur) {
        let defaults = UserDefaults.standard
        guard let place = defaults.string(forKey: "SouffleurDemo").flatMap(PrompterPlacement.init(rawValue:)) else { return }
        app.prompter.placementOverride = place
        app.prompter.demoVoice = defaults.bool(forKey: "SouffleurDemoVoice")
        app.prompter.demoStop = defaults.object(forKey: "SouffleurDemoStop") != nil ? defaults.integer(forKey: "SouffleurDemoStop") : nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            app.prompt(text: app.store.documents.first(where: { $0.text.hasPrefix("# Welcome to Souffleur") })?.text ?? "", title: "Welcome to Souffleur")
        }
        if defaults.bool(forKey: "SouffleurDemoHover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { app.prompter.state.isHovering = true }
        }
    }
}
