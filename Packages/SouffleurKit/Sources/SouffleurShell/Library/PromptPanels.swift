import SouffleurCore
import SwiftUI

/// The big round button in the corner of the script: prompt, then pause and play.
struct PlayButton: View {
    let app: Souffleur
    @State private var pressed = false

    var body: some View {
        let phase = app.prompter.state.phase
        let rolling = phase == .rolling || { if case .countdown = phase { return true } else { return false } }()
        Button { app.playPause() } label: {
            Image(systemName: rolling ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: rolling ? 0 : 2)
                .frame(width: 84, height: 84)
                .background(Circle().fill(LinearGradient(colors: [Theme.accent, Theme.fuchsia], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                .shadow(color: Theme.accent.opacity(0.55), radius: 18, y: 6)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressStyle())
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!app.canPrompt)
        .opacity(app.canPrompt ? 1 : 0.45)
        .help(rolling ? String(localized: "Pause (⌘↩)", bundle: .module) : String(localized: "Prompt this script (⌘↩, or ⌃⌥⌘P from any app)", bundle: .module))
        .accessibilityLabel(rolling ? String(localized: "Pause", bundle: .module) : String(localized: "Prompt", bundle: .module))
    }
}

/// Presses in a little, like a real button.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Below the script: the speed, from tortoise to hare, and the switch to follow the voice instead.
struct SpeedPanel: View {
    let document: ScriptDocument
    @Binding var pace: Double
    @Binding var mode: String
    let lastSummary: String

    private var follows: Binding<Bool> {
        Binding(get: { mode == ScrollMode.voice.rawValue }, set: { mode = $0 ? ScrollMode.voice.rawValue : ScrollMode.auto.rawValue })
    }

    var body: some View {
        let words = document.wordCount
        let voice = mode == ScrollMode.voice.rawValue
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Speed", bundle: .module)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle(isOn: follows) {
                    Label(String(localized: "Follow my voice", bundle: .module), systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.accent)
                .help(String(localized: "The script follows your words, recognised on your Mac, instead of a steady speed.", bundle: .module))
            }
            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $pace, in: Preferences.minimumPace...Preferences.maximumPace)
                    .tint(Theme.accent)
                Image(systemName: "hare.fill")
                    .foregroundStyle(.secondary)
            }
            .disabled(voice)
            .opacity(voice ? 0.4 : 1)
            HStack(spacing: 12) {
                Text(voice
                     ? String(localized: "Follows your voice · \(words) words", bundle: .module)
                     : String(localized: "\(Int(pace.rounded())) words a minute · \(words) words · \(Pace.clock(Pace.readingTime(words: words, wordsPerMinute: pace)))", bundle: .module))
                Spacer()
                if !lastSummary.isEmpty {
                    Label {
                        Text("Last take: \(lastSummary)", bundle: .module)
                    } icon: {
                        Image(systemName: "record.circle").foregroundStyle(Theme.accent)
                    }
                }
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}
