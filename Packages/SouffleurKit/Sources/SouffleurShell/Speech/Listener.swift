@preconcurrency import AVFoundation
import Foundation
import NaturalLanguage
@preconcurrency import Speech

/// What the listener reports, always on the main queue.
public enum ListenerEvent: Sendable {
    /// Microphone level from 0 to 1, and whether it sounds like speech.
    case level(Float, speaking: Bool)
    /// The latest words heard, most recent last; `final` holds a finished sentence the first time it is reported.
    case heard(String, final: String?)
    /// Something the reader should know while the listener gets ready, such as a voice model being prepared.
    case status(String?)
    case failed(ListenerFailure)
}

public enum ListenerFailure: Error, Sendable, Equatable {
    case microphoneDenied
    case speechDenied
    case languageUnsupported(String)
    case microphoneUnavailable

    public var message: String {
        switch self {
        case .microphoneDenied: String(localized: "Souffleur can't hear you: microphone access is off.", bundle: .module)
        case .speechDenied: String(localized: "Speech recognition is off for Souffleur.", bundle: .module)
        case .languageUnsupported(let name): String(localized: "Voice follow can't hear \(name) on this Mac yet. Rolling at your pace instead.", bundle: .module)
        case .microphoneUnavailable: String(localized: "No microphone is available.", bundle: .module)
        }
    }

    /// The System Settings pane that fixes it, if any.
    public var settingsURL: URL? {
        switch self {
        case .microphoneDenied: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechDenied: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        default: nil
        }
    }
}

/// Listens to the microphone while the prompter runs: the level for voice pace and the meter, and, for voice follow,
/// the words recognised on this Mac. Nothing runs while the prompter is closed.
public final class Listener: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var recognizer: RecognitionEngine?
    private var onEvent: (@Sendable (ListenerEvent) -> Void)?
    private var isRunning = false
    // Voice activity: an adaptive noise floor, and speech when the level stays well above it.
    private var noiseFloor: Float = -50
    private var lastVoice: TimeInterval = 0
    private var lastLevelReport: TimeInterval = 0

    public init() {}

    /// Starts listening. With `recognize`, words are recognised in `locale`, helped by the script's vocabulary.
    public func start(recognize: Bool, locale: Locale, vocabulary: [String], onEvent: @escaping @Sendable (ListenerEvent) -> Void) async {
        stop()
        self.onEvent = onEvent
        guard await Permissions.microphone() else { return report(.failed(.microphoneDenied)) }
        var engineForSpeech: RecognitionEngine?
        if recognize {
            guard await Permissions.speech() else { return report(.failed(.speechDenied)) }
            do {
                engineForSpeech = try await RecognitionEngine.make(locale: locale, vocabulary: vocabulary, report: { [weak self] event in self?.report(event) })
            } catch {
                let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                report(.failed(.languageUnsupported(name)))
            }
        }
        lock.withLock { recognizer = engineForSpeech }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return report(.failed(.microphoneUnavailable)) }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
        } catch {
            input.removeTap(onBus: 0)
            report(.failed(.microphoneUnavailable))
        }
    }

    public func stop() {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
        let current = lock.withLock { () -> RecognitionEngine? in
            defer { recognizer = nil }
            return recognizer
        }
        current?.stop()
        onEvent = nil
    }

    private func report(_ event: ListenerEvent) {
        let handler = onEvent
        DispatchQueue.main.async { handler?(event) }
    }

    /// On the audio thread: the level, voice activity, and the buffer for the recogniser.
    private func process(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { recognizer }?.append(buffer)
        guard let samples = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = sqrt(sum / Float(count))
        let decibels = 20 * log10(max(rms, 0.000_01))
        let now = ProcessInfo.processInfo.systemUptime
        // The floor follows quiet moments quickly and loud ones slowly, so speech never becomes the floor.
        noiseFloor = decibels < noiseFloor ? noiseFloor * 0.9 + decibels * 0.1 : noiseFloor * 0.998 + decibels * 0.002
        noiseFloor = min(max(noiseFloor, -80), -30)
        if decibels > noiseFloor + 12, decibels > -52 { lastVoice = now }
        let speaking = now - lastVoice < 0.45
        guard now - lastLevelReport > 1.0 / 20 else { return }
        lastLevelReport = now
        let level = min(max((decibels + 60) / 50, 0), 1)
        report(.level(level, speaking: speaking))
    }

    /// The language to listen in: the one chosen in Settings, or the one the script is written in.
    public static func locale(for text: String, preference: String) -> Locale {
        if preference != "auto" { return Locale(identifier: preference) }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(4000)))
        guard let language = recognizer.dominantLanguage?.rawValue else { return Locale.current }
        // Keep the user's region when it goes with that language (fr_CH for a French script in Switzerland).
        if Locale.current.language.languageCode?.identifier == language { return Locale.current }
        return Locale(identifier: language)
    }

    /// The distinct words of the script, longest first, for the recogniser's contextual vocabulary.
    public static func vocabulary(of words: [String], limit: Int = 100) -> [String] {
        var seen = Set<String>()
        let unique = words.filter { $0.count > 3 && seen.insert($0.lowercased()).inserted }
        return Array(unique.sorted { $0.count > $1.count }.prefix(limit))
    }
}

enum Permissions {
    static func microphone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    static func speech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }
}
