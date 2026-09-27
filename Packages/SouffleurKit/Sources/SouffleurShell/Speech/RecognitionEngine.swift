@preconcurrency import AVFoundation
import Foundation
@preconcurrency import Speech

/// Speech recognition on this Mac: SpeechAnalyzer on macOS 26, SFSpeechRecognizer before. Both report the latest
/// words heard through the same callback.
class RecognitionEngine: @unchecked Sendable {
    func append(_ buffer: AVAudioPCMBuffer) {}
    func stop() {}

    /// SpeechAnalyzer when its model for the language is already on the Mac; otherwise SFSpeechRecognizer, which is
    /// ready at once. A take never waits for a download.
    static func make(locale: Locale, vocabulary: [String], report: @escaping @Sendable (ListenerEvent) -> Void) async throws -> RecognitionEngine {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale),
           await AssetInventory.status(forModules: [AnalyzerEngine.transcriber(for: supported)]) == .installed {
            let engine = AnalyzerEngine()
            do {
                try await engine.start(locale: supported, vocabulary: vocabulary, report: report)
                return engine
            } catch {
                engine.stop()
            }
        }
        guard let engine = LegacyEngine(locale: locale, vocabulary: vocabulary, report: report) else {
            throw ListenerFailure.languageUnsupported(locale.identifier)
        }
        engine.begin()
        return engine
    }
}

/// The last `count` words of a text.
func tail(_ text: String, words count: Int) -> String {
    text.split(whereSeparator: { $0.isWhitespace }).suffix(count).joined(separator: " ")
}

@available(macOS 26, *)
final class AnalyzerEngine: RecognitionEngine, @unchecked Sendable {
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: AVAudioConverter?
    private var format: AVAudioFormat?
    private var results: Task<Void, Never>?
    private let lock = NSLock()

    static func transcriber(for locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
    }

    func start(locale: Locale, vocabulary: [String], report: @escaping @Sendable (ListenerEvent) -> Void) async throws {
        let transcriber = Self.transcriber(for: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            report(.status(String(localized: "Preparing the voice model…", bundle: .module)))
            try await request.downloadAndInstall()
            report(.status(nil))
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering))
        let context = AnalysisContext()
        context.contextualStrings[.general] = vocabulary
        try? await analyzer.setContext(context)
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        lock.withLock {
            self.format = format
            self.continuation = continuation
        }
        try await analyzer.prepareToAnalyze(in: format)
        try await analyzer.start(inputSequence: stream)
        self.analyzer = analyzer
        results = Task {
            var finished = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finished = tail(finished + " " + text, words: 24)
                        report(.heard(finished, final: text))
                    } else {
                        report(.heard(tail(finished + " " + text, words: 24), final: nil))
                    }
                }
            } catch {}
        }
    }

    override func append(_ buffer: AVAudioPCMBuffer) {
        let (format, continuation) = lock.withLock { (self.format, self.continuation) }
        guard let continuation else { return }
        guard let format, buffer.format != format else {
            continuation.yield(AnalyzerInput(buffer: buffer))
            return
        }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { return }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, output.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: output)) }
    }

    override func stop() {
        let continuation = lock.withLock { () -> AsyncStream<AnalyzerInput>.Continuation? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.finish()
        results?.cancel()
        let analyzer = self.analyzer
        self.analyzer = nil
        Task { await analyzer?.cancelAndFinishNow() }
    }
}

/// SFSpeechRecognizer, restarted after each sentence or silence so it listens for as long as the prompter runs.
final class LegacyEngine: RecognitionEngine, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let vocabulary: [String]
    private let report: @Sendable (ListenerEvent) -> Void
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var stopped = false
    private var finished = ""

    /// Nil unless the language can be recognised on this Mac: Souffleur never sends a voice to a server.
    init?(locale: Locale, vocabulary: [String], report: @escaping @Sendable (ListenerEvent) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else { return nil }
        self.recognizer = recognizer
        self.vocabulary = vocabulary
        self.report = report
    }

    func begin() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = vocabulary
        request.addsPunctuation = false
        request.requiresOnDeviceRecognition = true
        lock.withLock { self.request = request }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                let recent = tail(self.finished + " " + text, words: 24)
                self.report(.heard(recent, final: result.isFinal ? text : nil))
                if result.isFinal {
                    self.finished = recent
                    self.restart()
                }
            } else if error != nil {
                self.restart()
            }
        }
    }

    private func restart() {
        let stop = lock.withLock { () -> Bool in
            request?.endAudio()
            request = nil
            return stopped
        }
        guard !stop else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, !self.lock.withLock({ self.stopped }) else { return }
            self.begin()
        }
    }

    override func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { request }?.append(buffer)
    }

    override func stop() {
        lock.withLock {
            stopped = true
            request?.endAudio()
            request = nil
        }
        task?.cancel()
        task = nil
    }
}
