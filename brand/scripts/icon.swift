// brand/scripts/icon.swift: draws the Souffleur icon, a slab of black glass with the notch at its top edge and the
// script beneath it, the line being read lit by the warm lamp of a prompter's box.
// Usage: swift brand/scripts/icon.swift <out.png> [size]
import AppKit

let args = CommandLine.arguments
let output = URL(fileURLWithPath: args.count > 1 ? args[1] : "icon.png")
let pixels = args.count > 2 ? Int(args[2])! : 1024

func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func g(_ colors: [CGColor], _ l: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: l)! }

/// The notch with its concave ears, hanging from `top` (y up).
func notch(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, ear: CGFloat, r: CGFloat) -> CGPath {
    let L = cx - w / 2, R = cx + w / 2, B = top - h, reach = min(r * 1.28, h - ear, w / 2), hd = reach * 0.36
    let p = CGMutablePath()
    p.move(to: CGPoint(x: L - ear, y: top)); p.addQuadCurve(to: CGPoint(x: L, y: top - ear), control: CGPoint(x: L, y: top))
    p.addLine(to: CGPoint(x: L, y: B + reach)); p.addCurve(to: CGPoint(x: L + reach, y: B), control1: CGPoint(x: L, y: B + hd), control2: CGPoint(x: L + hd, y: B))
    p.addLine(to: CGPoint(x: R - reach, y: B)); p.addCurve(to: CGPoint(x: R, y: B + reach), control1: CGPoint(x: R - hd, y: B), control2: CGPoint(x: R, y: B + hd))
    p.addLine(to: CGPoint(x: R, y: top - ear)); p.addQuadCurve(to: CGPoint(x: R + ear, y: top), control: CGPoint(x: R, y: top)); p.closeSubpath()
    return p
}

func capsule(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
}

let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow and the slab of black glass.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: c(0x000000, 0.45))
ctx.addPath(bodyPath); ctx.setFillColor(c(0x0A0A0B)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
ctx.drawLinearGradient(g([c(0x26262A), c(0x111113), c(0x050506)], [0, 0.5, 1]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// A broad, soft reflection from the upper left, like polished glass.
ctx.drawLinearGradient(g([c(0xFFFFFF, 0.06), c(0xFFFFFF, 0)], [0, 1]), start: CGPoint(x: 100, y: 924), end: CGPoint(x: 520, y: 420), options: [])

// The lamp: warm light pouring from under the notch onto the glass.
let notchTop: CGFloat = 924, notchHeight: CGFloat = 132
ctx.drawRadialGradient(g([c(0xFFB447, 0.34), c(0xFF9A2E, 0.12), c(0xFF9A2E, 0)], [0, 0.45, 1]),
                       startCenter: CGPoint(x: 512, y: notchTop - notchHeight), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: notchTop - notchHeight), endRadius: 470, options: [])

// The script: the line being read in the lamp's colour, the lines to come fading away below it.
let lines: [(y: CGFloat, w: CGFloat, color: CGColor, glow: Bool)] = [
    (672, 548, c(0xFFB447), true),
    (560, 624, c(0xF4F4F7, 0.82), false),
    (448, 480, c(0xF4F4F7, 0.5), false),
    (336, 566, c(0xF4F4F7, 0.24), false),
    (224, 420, c(0xF4F4F7, 0.1), false),
]
for line in lines {
    ctx.saveGState()
    if line.glow { ctx.setShadow(offset: .zero, blur: 46, color: c(0xFF9A2E, 0.85)) }
    ctx.addPath(capsule(cx: 512, cy: line.y, w: line.w, h: 50))
    ctx.setFillColor(line.color)
    ctx.fillPath()
    ctx.restoreGState()
}
// A brighter heart on the lit line.
ctx.saveGState()
ctx.addPath(capsule(cx: 512, cy: 672, w: 548, h: 50)); ctx.clip()
ctx.drawLinearGradient(g([c(0xFFE3B0, 0.9), c(0xFFB447, 0), c(0xFF8F2A, 0.35)], [0, 0.55, 1]), start: CGPoint(x: 512, y: 697), end: CGPoint(x: 512, y: 647), options: [])
ctx.restoreGState()

// The notch itself: solid black, recessed, with a warm rim where the lamp catches its lower edge.
let window = notch(cx: 512, top: notchTop, w: 318, h: notchHeight, ear: 28, r: 58)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: c(0x000000, 0.9))
ctx.addPath(window); ctx.setFillColor(c(0x000000)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(window); ctx.setLineWidth(5); ctx.replacePathWithStrokedPath(); ctx.clip()
ctx.drawLinearGradient(g([c(0xFFFFFF, 0), c(0xFFC878, 0.25), c(0xFFD9A0, 0.9)], [0, 0.55, 1]), start: CGPoint(x: 512, y: notchTop), end: CGPoint(x: 512, y: notchTop - notchHeight), options: [])
ctx.restoreGState()
// The camera, a dark lens in the notch.
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: 512 - 17, y: notchTop - 70 - 17, width: 34, height: 34))
ctx.setFillColor(c(0x101826)); ctx.fillPath()
ctx.addEllipse(in: CGRect(x: 512 - 7, y: notchTop - 70 - 1, width: 9, height: 9))
ctx.setFillColor(c(0x5A6E90, 0.8)); ctx.fillPath()
ctx.restoreGState()

// Edge of the slab: a fine highlight on the rim, like polished glass.
ctx.addPath(bodyPath); ctx.setLineWidth(4); ctx.replacePathWithStrokedPath(); ctx.clip()
ctx.drawLinearGradient(g([c(0xFFFFFF, 0.32), c(0xFFFFFF, 0.04), c(0xFFFFFF, 0.1)], [0, 0.5, 1]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: output)
