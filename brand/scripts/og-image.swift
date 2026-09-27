// brand/scripts/og-image.swift <icon-1024.png> <out.png>: the 1280 x 640 image that stands for Souffleur when a link is
// shared: the icon in stage light, the name and the signature.
import AppKit

let args = CommandLine.arguments
let icon = NSImage(contentsOfFile: args[1])!
let size = NSSize(width: 1280, height: 640)
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
context.drawRadialGradient(glow, startCenter: CGPoint(x: 330, y: 320), startRadius: 0, endCenter: CGPoint(x: 330, y: 320), endRadius: 420, options: [])
icon.draw(in: NSRect(x: 110, y: 100, width: 440, height: 440))
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
