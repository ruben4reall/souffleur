import AppKit
import SouffleurCore

/// Stage light along the prompter's rim: a conic gradient of violet and fuchsia that turns slowly, seen through the
/// outline twice, as a fine line and as a soft halo. The halo's mask is a stack of ever wider, ever fainter strokes,
/// which falls off like a blur without any filter. The render server turns it; the app only changes how bright it is.
final class GlowView: NSView {
    private let line = CALayer()
    private let halo = CALayer()
    private let lineGradient = CAGradientLayer()
    private let haloGradient = CAGradientLayer()
    private let lineRim = CAShapeLayer()
    private let haloMask = CALayer()
    /// Width and opacity of each stroke of the halo, widest and faintest first: close steps, so no band shows.
    private static let haloStrokes: [(width: CGFloat, alpha: Float)] = (0..<12).map { step in
        let t = CGFloat(step) / 11
        return (width: 34 - 30 * t, alpha: Float(0.035 + 0.1 * t * t))
    }
    private let haloRims: [CAShapeLayer] = (0..<12).map { _ in CAShapeLayer() }
    private var spinning = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.opacity = 0
        for (container, gradient) in [(halo, haloGradient), (line, lineGradient)] {
            gradient.type = .conic
            gradient.colors = Theme.glowColors
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 0.5, y: 0)
            container.addSublayer(gradient)
            layer?.addSublayer(container)
        }
        for (rim, stroke) in zip(haloRims + [lineRim], Self.haloStrokes + [(2, 1)]) {
            rim.fillColor = nil
            rim.strokeColor = NSColor.black.cgColor
            rim.lineWidth = stroke.width
            rim.opacity = stroke.alpha
            rim.lineJoin = .round
            rim.lineCap = .round
        }
        haloRims.forEach { haloMask.addSublayer($0) }
        halo.mask = haloMask
        line.mask = lineRim
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Sizes the light around a centre, big enough to cover the view as it turns.
    func configure(center: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = hypot(bounds.width, bounds.height) * 1.2
        for container in [line, halo] { container.frame = bounds }
        haloMask.frame = bounds
        for rim in haloRims + [lineRim] { rim.frame = bounds }
        for gradient in [lineGradient, haloGradient] {
            gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            gradient.position = center
        }
        CATransaction.commit()
    }

    /// The outlines the light runs along; the presentation morphs them with the prompter.
    var rimLayers: [CAShapeLayer] { haloRims + [lineRim] }

    /// How bright the light is, from 0 (off) to 1, eased.
    func setIntensity(_ value: CGFloat, duration: CFTimeInterval = 0.25) {
        guard let layer else { return }
        let target = Float(max(0, min(1, value)))
        if target > 0, !spinning { spin(true) }
        CATransaction.begin()
        if target == 0 {
            CATransaction.setCompletionBlock { [weak self] in
                MainActor.assumeIsolated {
                    if self?.layer?.opacity == 0 { self?.spin(false) }
                }
            }
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
        fade.toValue = target
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = target
        layer.add(fade, forKey: "opacity")
        CATransaction.commit()
    }

    private func spin(_ on: Bool) {
        spinning = on
        for gradient in [lineGradient, haloGradient] {
            guard on else { gradient.removeAnimation(forKey: "spin"); continue }
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { continue }
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = 0
            turn.toValue = -2 * Double.pi
            turn.duration = 7
            turn.repeatCount = .infinity
            gradient.add(turn, forKey: "spin")
        }
    }
}
