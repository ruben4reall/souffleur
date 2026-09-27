import AppKit
import AVFoundation
import CoreImage
import ScreenCaptureKit

// scripts/record-reel.swift: films one window of Souffleur (the prompter) with ScreenCaptureKit, lays each frame on a
// real desktop picture at the notch, and writes the H.264 video of the website's "See it in action". Only the prompter
// window is captured, never the screen. scripts/capture-site.sh runs it.
// usage: record-reel <window-id> <desktop.png (3024 wide, a MacBook Pro 14 screen)> <out.mp4> <seconds> [poster.png]
// The poster is the frame six seconds in.
let args = CommandLine.arguments
guard args.count >= 5, let windowID = CGWindowID(args[1]), let seconds = Double(args[4]) else { print("usage"); exit(2) }
let posterURL = args.count > 5 ? URL(fileURLWithPath: args[5]) : nil
let desktop = CIImage(contentsOf: URL(fileURLWithPath: args[2]))!
let out = URL(fileURLWithPath: args[3])
try? FileManager.default.removeItem(at: out)

// The video shows 900 x 560 points around the notch, at 1.5 pixels a point.
let scale: CGFloat = 1.5
let region = CGSize(width: 900, height: 560)
let size = CGSize(width: region.width * scale, height: region.height * scale)
let screenWidth: CGFloat = 1512
// The desktop picture is at 2x; crop the top middle and scale to 1.5x.
let desktopCrop = desktop
    .cropped(to: CGRect(x: (screenWidth - region.width) / 2 * 2, y: desktop.extent.height - region.height * 2, width: region.width * 2, height: region.height * 2))
    .transformed(by: CGAffineTransform(translationX: -(screenWidth - region.width) / 2 * 2, y: -(desktop.extent.height - region.height * 2)))
    .transformed(by: CGAffineTransform(scaleX: scale / 2, y: scale / 2))
let context = CIContext()

final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    var start: CMTime?
    var frames = 0
    let place: (CIImage) -> CIImage
    let context: CIContext
    let size: CGSize
    var poster: URL?

    init(out: URL, size: CGSize, context: CIContext, poster: URL?, place: @escaping (CIImage) -> CIImage) throws {
        self.poster = poster
        writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_400_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
        ])
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        self.place = place
        self.context = context
        self.size = size
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sample.isValid, let buffer = sample.imageBuffer else { return }
        // Only complete frames.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) != .complete { return }
        let time = sample.presentationTimeStamp
        if start == nil {
            writer.startWriting()
            writer.startSession(atSourceTime: time)
            start = time
        }
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var target: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &target)
        guard let target else { return }
        let frame = place(CIImage(cvPixelBuffer: buffer))
        context.render(frame, to: target, bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        if let url = poster, let start, CMTimeGetSeconds(CMTimeSubtract(time, start)) >= 6,
           let image = context.createCGImage(frame, from: CGRect(origin: .zero, size: size)) {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
            poster = nil
        }
        adaptor.append(target, withPresentationTime: time)
        frames += 1
    }
}

let done = DispatchSemaphore(value: 0)
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else { print("no window \(windowID)"); exit(1) }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * 2)
        config.height = Int(window.frame.height * 2)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        config.shouldBeOpaque = false
        config.ignoreShadowsSingleWindow = false
        // The window's place in the video: centred, its top on the top edge, at 1.5x.
        let windowSize = window.frame.size
        let place: (CIImage) -> CIImage = { frame in
            let scaled = frame.transformed(by: CGAffineTransform(scaleX: scale / 2, y: scale / 2))
            let x = (size.width - windowSize.width * scale) / 2
            let y = size.height - windowSize.height * scale
            return scaled.transformed(by: CGAffineTransform(translationX: x, y: y)).composited(over: desktopCrop)
        }
        let recorder = try Recorder(out: out, size: size, context: context, poster: posterURL, place: place)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: DispatchQueue(label: "frames"))
        try await stream.startCapture()
        try await Task.sleep(for: .seconds(seconds))
        try await stream.stopCapture()
        recorder.input.markAsFinished()
        await recorder.writer.finishWriting()
        print("frames", recorder.frames, "status", recorder.writer.status.rawValue, recorder.writer.error as Any)
    } catch { print("error", error) }
    done.signal()
}
done.wait()
