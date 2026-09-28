// scripts/compose.swift <desktop.png> <panel.png> <out.png> [cropHeight] [hang]: lays a capture of the notch prompter
// on the top of a real desktop, centred where the notch is, `hang` pixels below the top edge (0: it grows out of the
// notch), with the MacBook's notch in front of it: a quick preview of a capture where it will be seen.
import AppKit

let args = CommandLine.arguments
let desktop = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let panel = NSImage(contentsOfFile: args[2])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let cropHeight = args.count > 4 ? Int(args[4])! : 700
let hang = args.count > 5 ? Int(args[5])! : 0
let width = desktop.width
let context = CGContext(data: nil, width: width, height: cropHeight, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// The top of the desktop.
context.draw(desktop, in: CGRect(x: 0, y: cropHeight - desktop.height, width: desktop.width, height: desktop.height))
// The panel, centred under the camera.
let x = (width - panel.width) / 2
context.draw(panel, in: CGRect(x: x, y: cropHeight - hang - panel.height, width: panel.width, height: panel.height))
// The MacBook's notch, which a screenshot never shows, in front: 185 x 32 points (370 x 64 pixels) at the top centre.
let notch = CGMutablePath()
let notchRect = CGRect(x: (width - 370) / 2, y: cropHeight - 64, width: 370, height: 64)
notch.move(to: CGPoint(x: notchRect.minX, y: notchRect.maxY))
notch.addLine(to: CGPoint(x: notchRect.minX, y: notchRect.minY + 16))
notch.addQuadCurve(to: CGPoint(x: notchRect.minX + 16, y: notchRect.minY), control: CGPoint(x: notchRect.minX, y: notchRect.minY))
notch.addLine(to: CGPoint(x: notchRect.maxX - 16, y: notchRect.minY))
notch.addQuadCurve(to: CGPoint(x: notchRect.maxX, y: notchRect.minY + 16), control: CGPoint(x: notchRect.maxX, y: notchRect.minY))
notch.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.maxY))
notch.closeSubpath()
context.addPath(notch)
context.setFillColor(CGColor(gray: 0, alpha: 1))
context.fillPath()
let image = context.makeImage()!
try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
