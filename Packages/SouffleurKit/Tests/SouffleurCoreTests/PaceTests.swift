import CoreGraphics
import Foundation
import Testing
@testable import SouffleurCore

struct PaceTests {
    @Test func readingTimeFollowsThePace() {
        #expect(Pace.readingTime(words: 300, wordsPerMinute: 150) == 120)
        #expect(Pace.readingTime(words: 0, wordsPerMinute: 150) == 0)
        #expect(Pace.readingTime(words: 10, wordsPerMinute: 0) == 0)
    }

    @Test func clockShowsMinutesAndSeconds() {
        #expect(Pace.clock(0) == "0:00")
        #expect(Pace.clock(65) == "1:05")
        #expect(Pace.clock(3_725) == "1:02:05")
        #expect(Pace.clock(-3) == "0:00")
    }

    @Test func meterMeasuresTheRecentPace() {
        var meter = PaceMeter(span: 10)
        let start = Date(timeIntervalSince1970: 0)
        meter.record(wordIndex: 0, at: start)
        meter.record(wordIndex: 25, at: start.addingTimeInterval(10))
        #expect(meter.wordsPerMinute == 150)
    }

    @Test func meterForgetsOldSamples() {
        var meter = PaceMeter(span: 10)
        let start = Date(timeIntervalSince1970: 0)
        meter.record(wordIndex: 0, at: start)
        meter.record(wordIndex: 100, at: start.addingTimeInterval(5))
        meter.record(wordIndex: 110, at: start.addingTimeInterval(25))
        meter.record(wordIndex: 120, at: start.addingTimeInterval(29))
        #expect(meter.wordsPerMinute == 150)
    }

    @Test func meterIsQuietWithoutEnoughTime() {
        var meter = PaceMeter(span: 10)
        meter.record(wordIndex: 3, at: Date(timeIntervalSince1970: 0))
        #expect(meter.wordsPerMinute == nil)
    }

    @Test func autoScrollSpeedTurnsPaceIntoPoints() {
        // 120 words a minute, 10 words a line, 30 points a line: 12 lines a minute, 6 points a second.
        #expect(Pace.pointsPerSecond(wordsPerMinute: 120, wordsPerLine: 10, lineHeight: 30) == 6)
    }
}

struct TakeSummaryTests {
    @Test func summarisesATake() {
        let start = Date(timeIntervalSince1970: 0)
        var recorder = TakeRecorder(totalWords: 200, start: start)
        recorder.record(wordIndex: 50, at: start.addingTimeInterval(20))
        recorder.record(wordIndex: 60, at: start.addingTimeInterval(32))
        recorder.record(wordIndex: 150, at: start.addingTimeInterval(60))
        recorder.heard("so um we uh launch")
        let summary = recorder.finish(at: start.addingTimeInterval(60))
        #expect(summary.duration == 60)
        #expect(summary.wordsRead == 150)
        #expect(summary.averageWordsPerMinute == 150)
        #expect(summary.coverage == 0.75)
        #expect(summary.longestPause == 28)
        #expect(summary.fillers == 2)
    }

    @Test func anEmptyTakeHasNoPace() {
        let start = Date(timeIntervalSince1970: 0)
        let summary = TakeRecorder(totalWords: 0, start: start).finish(at: start)
        #expect(summary.averageWordsPerMinute == 0)
        #expect(summary.coverage == 0)
    }
}

struct NotchGeometryTests {
    @Test func readsTheHardwareNotch() {
        let notch = NotchMetrics.resolve(screenWidth: 1512, safeAreaTop: 32, leftAreaWidth: 662, rightAreaWidth: 662, menuBarHeight: 37)
        #expect(notch == NotchMetrics(width: 188, height: 32, centerX: 756, isHardware: true))
    }

    @Test func drawsItsOwnNotchWithoutHardware() {
        let notch = NotchMetrics.resolve(screenWidth: 2560, safeAreaTop: 0, leftAreaWidth: nil, rightAreaWidth: nil, menuBarHeight: 25)
        #expect(notch == NotchMetrics(width: 180, height: 25, centerX: 1280, isHardware: false))
    }

    @Test func thePrompterHangsFromTheNotchAndWidensBelowIt() {
        let notch = NotchMetrics(width: 188, height: 32, centerX: 756, isHardware: true)
        let layout = PrompterLayout(notch: notch, width: 520, textHeight: 150)
        let closed = layout.shape(open: false)
        let open = layout.shape(open: true)
        #expect(closed.width == 188 && closed.height == 32 && closed.gap == 0)
        #expect(open.width == 520 && open.height == 32 + 150 && open.gap == 0)
        #expect(layout.textFrame.minY == 32)
        #expect(layout.textFrame.width == 520)
    }

    @Test func withoutANotchThePrompterFloatsUnderTheMenuBar() {
        let notch = NotchMetrics(width: 180, height: 25, centerX: 1280, isHardware: false)
        let layout = PrompterLayout(notch: notch, width: 520, textHeight: 150)
        let open = layout.shape(open: true)
        #expect(open.gap > 25)
        #expect(open.isFloating)
        #expect(layout.textFrame.minY == open.gap)
    }

    @Test func theRimLeavesOutTheEdgeAgainstTheScreen() {
        let hanging = PrompterShape(width: 200, height: 100, earRadius: 10, cornerRadius: 20)
        let rim = PrompterPath.rim(hanging, centerX: 300)
        // Open: it starts at the left ear on the top edge and ends at the right one.
        #expect(rim.currentPoint == CGPoint(x: 410, y: 0))
        let floating = PrompterShape(width: 200, height: 100, earRadius: 0, cornerRadius: 20, gap: 30)
        #expect(PrompterPath.rim(floating, centerX: 300).boundingBoxOfPath == PrompterPath.make(floating, centerX: 300).boundingBoxOfPath)
    }

    @Test func theOutlineIsClosedAndCentred() {
        let shape = PrompterShape(width: 200, height: 100, earRadius: 10, cornerRadius: 20)
        let box = PrompterPath.make(shape, centerX: 300).boundingBoxOfPath
        #expect(abs(box.midX - 300) < 0.5)
        #expect(abs(box.width - 220) < 0.5)
        #expect(abs(box.height - 100) < 0.5)
    }
}

struct RemoteProtocolTests {
    @Test func parsesARequestLineWithItsQuery() throws {
        let raw = "GET /command?token=abc123&action=faster HTTP/1.1\r\nHost: 192.168.1.4:7575\r\nAccept: */*\r\n\r\n"
        let request = try #require(HTTPRequest(Data(raw.utf8)))
        #expect(request.method == "GET")
        #expect(request.path == "/command")
        #expect(request.query["token"] == "abc123")
        #expect(request.query["action"] == "faster")
        #expect(request.headers["host"] == "192.168.1.4:7575")
    }

    @Test func rejectsAnIncompleteRequest() {
        #expect(HTTPRequest(Data("GET /command HTTP/1.1\r\nHost: x".utf8)) == nil)
        #expect(HTTPRequest(Data("nonsense\r\n\r\n".utf8)) == nil)
    }

    @Test func commandsHaveStableNames() {
        #expect(RemoteCommand(rawValue: "toggle") == .toggle)
        #expect(RemoteCommand.allCases.map(\.rawValue) == ["toggle", "faster", "slower", "back", "forward", "restart"])
    }

    @Test func stateEncodesToJSON() throws {
        let state = RemoteState(title: "Keynote", isRolling: true, progress: 0.5, wordsPerMinute: 140, line: "Hello there", remaining: 42)
        let json = try #require(String(data: JSONEncoder().encode(state), encoding: .utf8))
        #expect(json.contains("\"title\":\"Keynote\""))
        #expect(try JSONDecoder().decode(RemoteState.self, from: Data(json.utf8)) == state)
    }

    @Test func tokensAreLongAndUnguessable() {
        let token = RemoteToken.make()
        #expect(token.count == 12)
        #expect(token != RemoteToken.make())
        #expect(RemoteToken.matches(token, token))
        #expect(!RemoteToken.matches(token, "nope"))
    }
}
