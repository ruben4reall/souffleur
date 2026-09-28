import AppKit
import AVFoundation
import CoreImage
import ScreenCaptureKit

// scripts/record-reel.swift: films one window of Souffleur (the prompter) with ScreenCaptureKit, lays each frame on a
// real desktop picture under the notch, and writes the H.264 video of the website's "See it in action". Only the
// prompter window is captured, never anything else on the screen. ScreenCaptureKit trims a window's transparent edges
// and puts what is left in the corner of the frame: that content is cut out and put back where the window is on
// screen, so the prompter keeps its exact place around the notch. scripts/capture-site.sh runs it.
// usage: record-reel <window-id> <desktop.png (3024 wide, a MacBook Pro 14 screen)> <out.mp4> <seconds> [poster.png]
// The poster is the frame six seconds in.
setvbuf(stdout, nil, _IONBF, 0)
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
// The MacBook's notch, the black camera housing a screenshot never shows: 185 x 32 points at the top centre (what
// macOS reports on a 14-inch MacBook Pro), its lower corners rounded. The prompter grows out of it.
let notchSize = CGSize(width: 185 * scale, height: 32 * scale)
let notchContext = CGContext(data: nil, width: Int(notchSize.width), height: Int(notchSize.height), bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let notchRadius = 8 * scale
let notchPath = CGMutablePath()
notchPath.move(to: CGPoint(x: 0, y: notchSize.height))
notchPath.addLine(to: CGPoint(x: 0, y: notchRadius))
notchPath.addQuadCurve(to: CGPoint(x: notchRadius, y: 0), control: CGPoint(x: 0, y: 0))
notchPath.addLine(to: CGPoint(x: notchSize.width - notchRadius, y: 0))
notchPath.addQuadCurve(to: CGPoint(x: notchSize.width, y: notchRadius), control: CGPoint(x: notchSize.width, y: 0))
notchPath.addLine(to: CGPoint(x: notchSize.width, y: notchSize.height))
notchPath.closeSubpath()
notchContext.addPath(notchPath)
notchContext.setFillColor(CGColor(gray: 0, alpha: 1))
notchContext.fillPath()
let notch = CIImage(cgImage: notchContext.makeImage()!)
    .transformed(by: CGAffineTransform(translationX: (size.width - notchSize.width) / 2, y: size.height - notchSize.height))

final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    var start: CMTime?
    var frames = 0
    let place: (CIImage, CGRect, CGFloat) -> CIImage
    let context: CIContext
    let size: CGSize
    var poster: URL?

    init(out: URL, size: CGSize, context: CIContext, poster: URL?, place: @escaping (CIImage, CGRect, CGFloat) -> CIImage) throws {
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

    var received = 0
    var statuses: [Int: Int] = [:]

    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        received += 1
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let raw = attachments.first?[.status] as? Int { statuses[raw, default: 0] += 1 }
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
        let info = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        let content = (info?.first?[.contentRect]).flatMap { CGRect(dictionaryRepresentation: $0 as! CFDictionary) }
            ?? CGRect(x: 0, y: 0, width: CGFloat(CVPixelBufferGetWidth(buffer)) / 2, height: CGFloat(CVPixelBufferGetHeight(buffer)) / 2)
        let scaleFactor = info?.first?[.scaleFactor] as? CGFloat ?? 2
        let frame = place(CIImage(cvPixelBuffer: buffer), content, scaleFactor)
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
        // The content, cut out of the frame (top-left points in, bottom-left pixels here), centred where the window is
        // on screen, its top on the window's top, at 1.5x.
        let windowFrame = window.frame
        let cropLeft = (screenWidth - region.width) / 2
        let place: (CIImage, CGRect, CGFloat) -> CIImage = { frame, content, factor in
            let pixels = CGRect(x: content.minX * factor, y: frame.extent.height - content.maxY * factor,
                                width: content.width * factor, height: content.height * factor)
            let cut = frame.cropped(to: pixels).transformed(by: CGAffineTransform(translationX: -pixels.minX, y: -pixels.minY))
            let scaled = cut.transformed(by: CGAffineTransform(scaleX: scale / factor, y: scale / factor))
            let x = (windowFrame.midX - cropLeft) * scale - content.width * scale / 2
            let y = size.height - (windowFrame.minY + content.height) * scale
            // The notch stays in front, as the camera housing does.
            return notch.composited(over: scaled.transformed(by: CGAffineTransform(translationX: x, y: y)).composited(over: desktopCrop))
        }
        let recorder = try Recorder(out: out, size: size, context: context, poster: posterURL, place: place)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: DispatchQueue(label: "frames"))
        try await stream.startCapture()
        try await Task.sleep(for: .seconds(seconds))
        try await stream.stopCapture()
        guard recorder.start != nil else {
            print("no frame written: \(recorder.received) buffers, statuses \(recorder.statuses)")
            exit(1)
        }
        recorder.input.markAsFinished()
        await recorder.writer.finishWriting()
        print("frames", recorder.frames, "status", recorder.writer.status.rawValue, recorder.writer.error as Any)
    } catch { print("error", error) }
    done.signal()
}
done.wait()
