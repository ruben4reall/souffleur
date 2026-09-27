// scripts/reel-frames.swift <in.mp4> <out-dir> <fps> <x> <y> <width> <height> <out-width>: writes the frames of a video
// as PNGs, cropped to a rectangle (top-left origin, in the video's pixels) and scaled, for the README's animation.
import AppKit
import AVFoundation

let args = CommandLine.arguments
guard args.count == 9, let fps = Double(args[3]), let x = Double(args[4]), let y = Double(args[5]),
      let width = Double(args[6]), let height = Double(args[7]), let outWidth = Double(args[8]) else {
    print("usage: reel-frames <in.mp4> <out-dir> <fps> <x> <y> <width> <height> <out-width>"); exit(2)
}
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let generator = AVAssetImageGenerator(asset: asset)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let done = DispatchSemaphore(value: 0)
Task {
    let duration = try await asset.load(.duration).seconds
    let count = Int(duration * fps)
    let outHeight = (height * outWidth / width).rounded()
    for index in 0..<count {
        let (image, _) = try await generator.image(at: CMTime(seconds: Double(index) / fps, preferredTimescale: 600))
        guard let crop = image.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else { continue }
        let context = CGContext(data: nil, width: Int(outWidth), height: Int(outHeight), bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(crop, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
        let name = out.appendingPathComponent(String(format: "frame-%04d.png", index))
        try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: name)
    }
    print("frames", count)
    done.signal()
}
done.wait()
