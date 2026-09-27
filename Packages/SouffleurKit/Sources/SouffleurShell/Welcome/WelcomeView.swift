import AppKit
import SouffleurCore
import SwiftUI

/// The first launch: what Souffleur does, how the script should move, and a first take with the welcome script.
public struct WelcomeView: View {
    let app: Souffleur
    @State private var step = 0
    @AppStorage(Preferences.Key.mode) private var mode = ScrollMode.voice.rawValue
    @Environment(\.dismiss) private var dismiss

    public init(app: Souffleur) { self.app = app }

    public var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: hello
                case 1: modes
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            footer
        }
        .frame(width: 560, height: 520)
        .background(background)
        .animation(.spring(duration: 0.45, bounce: 0.1), value: step)
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Theme.accent.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 360)
        }
        .ignoresSafeArea()
    }

    private var hello: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: Theme.accent.opacity(0.35), radius: 24, y: 8)
            VStack(spacing: 6) {
                Text("Souffleur").font(.system(size: 30, weight: .bold))
                Text("Your lines, right under the camera.", bundle: .module)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 14) {
                feature("waveform", String(localized: "It follows your voice", bundle: .module), String(localized: "The words you say light up and the script keeps up with you.", bundle: .module))
                feature("macbook", String(localized: "It lives in the notch", bundle: .module), String(localized: "Read right under the lens and keep eye contact.", bundle: .module))
                feature("iphone.gen3", String(localized: "It's yours to drive", bundle: .module), String(localized: "Shortcuts, a presentation clicker or your phone.", bundle: .module))
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 60)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var modes: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("How should the script move?", bundle: .module).font(.system(size: 22, weight: .bold))
                Text("You can change it for every take.", bundle: .module).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                ForEach([ScrollMode.voice, .pace, .auto]) { option in
                    Button { mode = option.rawValue } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(mode == option.rawValue ? Color.white : Theme.accent)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(mode == option.rawValue ? Theme.accent : Theme.accent.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(option.title).font(.system(size: 14, weight: .semibold))
                                    if option == .voice {
                                        Text("Recommended", bundle: .module)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Theme.fuchsia)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(Theme.accent.opacity(0.16)))
                                    }
                                }
                                Text(option.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(mode == option.rawValue ? 0.07 : 0.035)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(mode == option.rawValue ? Theme.accent : .clear, lineWidth: 1.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(ScrollMode(rawValue: mode)?.listens == true
                 ? String(localized: "Souffleur will ask to use the microphone. Your voice is processed on your Mac and never recorded.", bundle: .module)
                 : String(localized: "No microphone needed.", bundle: .module))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 56)
    }

    private var ready: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 6) {
                Text("You're ready.", bundle: .module).font(.system(size: 24, weight: .bold))
                Text("Press Prompt, look at the camera, and speak.", bundle: .module).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                keys("⌃⌥⌘P", String(localized: "Prompt, play or pause, from any app", bundle: .module))
                keys("⌃⌥⌘H", String(localized: "Show or hide the prompter", bundle: .module))
                keys("⌘↩", String(localized: "Prompt the script you're writing", bundle: .module))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
        }
        .padding(.horizontal, 70)
    }

    private func keys(_ keys: String, _ label: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 70, alignment: .leading)
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index == step ? Theme.accent : Color.primary.opacity(0.15))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            Spacer()
            if step > 0 {
                Button(String(localized: "Back", bundle: .module)) { step -= 1 }
                    .controlSize(.large)
            }
            Button(step == 2 ? String(localized: "Try the Welcome Script", bundle: .module) : String(localized: "Continue", bundle: .module)) {
                next()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(.white)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private func next() {
        switch step {
        case 0: step = 1
        case 1:
            let listens = ScrollMode(rawValue: mode)?.listens == true
            step = 2
            if listens { Task { _ = await Permissions.microphone(); if mode == ScrollMode.voice.rawValue { _ = await Permissions.speech() } } }
        default:
            Preferences.welcomed = true
            dismiss()
            if let welcome = app.store.documents.first(where: { $0.text == ScriptStore.welcomeScript }) {
                app.store.selection = welcome.id
            }
            app.showLibrary()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { app.promptSelected() }
        }
    }
}
