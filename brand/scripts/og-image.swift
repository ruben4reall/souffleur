// brand/scripts/og-image.swift <icon-1024.png> <out.png> [width height]: the image that stands for Souffleur when a
// link is shared (1280 x 640), or the README's header (1600 x 440): the icon in stage light, the name and the signature.
import AppKit

let args = CommandLine.arguments
let icon = NSImage(contentsOfFile: args[1])!
let size = args.count > 4 ? NSSize(width: Double(args[3])!, height: Double(args[4])!) : NSSize(width: 1280, height: 640)
// Everything is laid out for 1280 x 640 and centred vertically in other sizes.
let dy = (size.height - 640) / 2
let dx = (size.width - 1280) / 2
let image = NSImage(size: size)
image.lockFocus()
let context = NSGraphicsContext.current!.cgContext
context.setFillColor(NSColor.black.cgColor)
context.fill(CGRect(origin: .zero, size: size))
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let glow = CGGradient(colorsSpace: space, colors: [
    NSColor(srgbRed: 0.70, green: 0.36, blue: 1, alpha: 0.42).cgColor,
    NSColor(srgbRed: 1, green: 0.35, blue: 0.78, alpha: 0.10).cgColor,
    NSColor(srgbRed: 1, green: 0.35, blue: 0.78, alpha: 0).cgColor,
] as CFArray, locations: [0, 0.55, 1])!
context.translateBy(x: dx, y: dy)
context.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 320), startRadius: 0, endCenter: CGPoint(x: 330, y: 320), endRadius: 420, options: [])
let iconSide = min(440, size.height - 40)
icon.draw(in: NSRect(x: 330 - iconSide / 2, y: 320 - iconSide / 2, width: iconSide, height: iconSide))
let name = NSAttributedString(string: "Souffleur", attributes: [
    .font: NSFont.systemFont(ofSize: 96, weight: .bold),
    .foregroundColor: NSColor.white,
    .kern: -2.0,
])
name.draw(at: NSPoint(x: 600, y: 330))
let line = NSAttributedString(string: "Your lines, right under the camera.", attributes: [
    .font: NSFont.systemFont(ofSize: 34, weight: .medium),
    .foregroundColor: NSColor(srgbRed: 0.80, green: 0.73, blue: 1, alpha: 1),
])
line.draw(at: NSPoint(x: 604, y: 270))
let foot = NSAttributedString(string: "Free and open source teleprompter for the Mac", attributes: [
    .font: NSFont.systemFont(ofSize: 24, weight: .regular),
    .foregroundColor: NSColor(white: 1, alpha: 0.55),
])
foot.draw(at: NSPoint(x: 604, y: 214))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
