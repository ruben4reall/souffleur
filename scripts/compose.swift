// scripts/compose.swift <desktop.png> <panel.png> <out.png> [cropHeight] [hang]: lays a capture of the notch prompter
// on the top of a real desktop, centred where the notch is, `hang` pixels below the top edge (64: 32 points at 2x, where
// the prompter hangs below a MacBook Pro's notch), for previews, the README and the website.
import AppKit

let args = CommandLine.arguments
let desktop = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let panel = NSImage(contentsOfFile: args[2])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let cropHeight = args.count > 4 ? Int(args[4])! : 700
let hang = args.count > 5 ? Int(args[5])! : 64
let width = desktop.width
let context = CGContext(data: nil, width: width, height: cropHeight, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// The top of the desktop.
context.draw(desktop, in: CGRect(x: 0, y: cropHeight - desktop.height, width: desktop.width, height: desktop.height))
// The panel hangs below the notch, centred.
let x = (width - panel.width) / 2
context.draw(panel, in: CGRect(x: x, y: cropHeight - hang - panel.height, width: panel.width, height: panel.height))
let image = context.makeImage()!
try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
