import AppKit
import SouffleurCore
import SwiftUI

/// The prompter hanging from the notch: it grows out of the camera housing with a spring, the text starts right under
/// the lens, and the camera row shows the time on the left and the voice on the right.
@MainActor
final class NotchPresentation: PrompterPresentation {
    let text = ScriptTextView()
    private let state: PrompterState
    private let panel = PrompterPanel(movable: false)
    private let canvas = NotchCanvas()
    private let backdrop = ShapeView()
    private let glow = GlowView()
    private let content = NSView()
    private let mask = CAShapeLayer()
    private var overlay: PassthroughHostingView<PrompterOverlay>?
    private var wings: [NSHostingView<AnyView>] = []
    private var layout: PrompterLayout?
    private var isOpen = false

    init(state: PrompterState) {
        self.state = state
        let root = NSView()
        root.wantsLayer = true
        panel.contentView = root
        root.addSubview(canvas)
        canvas.wantsLayer = true
        canvas.addSubview(backdrop)
        canvas.addSubview(glow)
        backdrop.shapeLayer.fillColor = NSColor.black.cgColor
        backdrop.shapeLayer.shadowColor = NSColor.black.cgColor
        backdrop.shapeLayer.shadowRadius = 12
        backdrop.shapeLayer.shadowOffset = CGSize(width: 0, height: -4)
        backdrop.shapeLayer.shadowOpacity = 0
        content.wantsLayer = true
        content.layer?.mask = mask
        canvas.addSubview(content)
        content.addSubview(text)
        canvas.onHover = { [weak state] inside in state?.isHovering = inside }
    }

    func refresh() {
        guard let screen = Screens.notch else { return }
        let notch = NotchMetrics.resolve(
            screenWidth: screen.frame.width,
            safeAreaTop: screen.safeAreaInsets.top,
            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
        let style = PrompterStyle.current()
        // Exactly the lines chosen: the one just read above, fading; the one being read; those to come, the last
        // fading into the edge.
        let textHeight = (style.lineHeight * CGFloat(Preferences.notchLines)).rounded()
        let layout = PrompterLayout(notch: notch, width: Preferences.notchWidth, textHeight: textHeight)
        self.layout = layout
        panel.sharingType = Preferences.hiddenFromCapture ? .none : .readOnly
        let size = layout.canvasSize
        panel.setFrame(NSRect(
            x: (screen.frame.minX + notch.centerX - size.width / 2).rounded(),
            y: screen.frame.maxY - size.height,
            width: size.width, height: size.height
        ), display: false)
        let bounds = NSRect(origin: .zero, size: size)
        canvas.frame = bounds
        backdrop.frame = bounds
        glow.frame = bounds
        content.frame = bounds
        mask.frame = bounds
        text.frame = flipped(layout.textFrame, in: size)
        text.readingInset = style.lineHeight
        text.hiddenTop = 0
        text.fadeTop = style.lineHeight * 0.9
        text.fadeBottom = style.lineHeight * 0.8
        text.horizontalInset = 18
        text.showsBand = false
        installOverlays(layout: layout, size: size)
        let path = outline(open: isOpen)
        let open = layout.shape(open: true)
        glow.configure(center: CGPoint(x: size.width / 2, y: size.height - open.gap - open.height / 2))
        glow.setColors(Preferences.stageLight)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.shapeLayer.path = path
        backdrop.shapeLayer.shadowPath = path
        mask.path = path
        glow.rimLayers.forEach { $0.path = outline(open: isOpen, rim: true) }
        CATransaction.commit()
        canvas.trackedRect = flipped(layout.frameOfOpenShape, in: size)
    }

    private func installOverlays(layout: PrompterLayout, size: CGSize) {
        overlay?.removeFromSuperview()
        let overlay = PassthroughHostingView(rootView: PrompterOverlay(state: state, showsStatusRow: !layout.notch.isHardware, scale: 0.8))
        overlay.sizingOptions = []
        overlay.frame = text.frame
        let state = self.state
        overlay.interactiveRects = { [weak overlay] in
            guard let overlay else { return [] }
            if state.failure != nil || state.summary != nil { return [overlay.bounds] }
            guard state.isHovering else { return [] }
            return [NSRect(x: overlay.bounds.midX - 90, y: 0, width: 180, height: 48)]
        }
        content.addSubview(overlay)
        self.overlay = overlay
        wings.forEach { $0.removeFromSuperview() }
        wings = []
        guard let frames = layout.wingFrames else { return }
        let left = NSHostingView(rootView: AnyView(TimerLabel(state: state).opacity(Preferences.showsTimer ? 1 : 0).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 14)))
        let right = NSHostingView(rootView: AnyView(LevelLabel(state: state).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 14)))
        for (view, frame) in [(left, frames.left), (right, frames.right)] {
            view.sizingOptions = []
            view.frame = flipped(frame, in: size)
            content.addSubview(view)
            wings.append(view)
        }
    }

    func present() {
        refresh()
        content.alphaValue = 0
        panel.orderFrontRegardless()
        isOpen = true
        morph(open: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            content.animator().alphaValue = 1
        }
    }

    func glow(_ intensity: CGFloat) {
        glow.setIntensity(intensity)
    }

    func closeNow() {
        isOpen = false
        state.isHovering = false
        glow.setIntensity(0, duration: 0)
        panel.orderOut(nil)
        text.halt()
    }

    func dismiss(completion: @escaping @MainActor () -> Void) {
        isOpen = false
        state.isHovering = false
        glow.setIntensity(0, duration: 0.15)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            content.animator().alphaValue = 0
        }
        // Held until the motion ends: the controller has already let go of this presentation.
        morph(open: false) {
            self.panel.orderOut(nil)
            self.text.halt()
            completion()
        }
    }

    private func morph(open: Bool, completion: (@MainActor () -> Void)? = nil) {
        let path = outline(open: open)
        let rim = outline(open: open, rim: true)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion?() } }
        let rims = glow.rimLayers.map { ($0, "path", rim) }
        for (layer, key, target) in [(backdrop.shapeLayer, "path", path), (backdrop.shapeLayer, "shadowPath", path), (mask, "path", path)] + rims {
            let animation = Motion.spring(open: open)
            animation.keyPath = key
            let current = key == "path" ? (layer.presentation()?.path ?? layer.path) : (layer.presentation()?.shadowPath ?? layer.shadowPath)
            animation.fromValue = current
            animation.toValue = target
            if key == "path" { layer.path = target } else { layer.shadowPath = target }
            layer.add(animation, forKey: key)
        }
        let shadow = Motion.spring(open: open)
        shadow.keyPath = "shadowOpacity"
        shadow.fromValue = backdrop.shapeLayer.presentation()?.shadowOpacity ?? backdrop.shapeLayer.shadowOpacity
        shadow.toValue = open ? 0.5 : 0
        backdrop.shapeLayer.shadowOpacity = open ? 0.5 : 0
        backdrop.shapeLayer.add(shadow, forKey: "shadowOpacity")
        CATransaction.commit()
    }

    private func outline(open: Bool, rim: Bool = false) -> CGPath {
        guard let layout else { return CGMutablePath() }
        let size = layout.canvasSize
        var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        let shape = layout.shape(open: open)
        let path = rim ? PrompterPath.rim(shape, centerX: size.width / 2) : PrompterPath.make(shape, centerX: size.width / 2)
        return path.copy(using: &flip) ?? path
    }

    private func flipped(_ rect: CGRect, in size: CGSize) -> NSRect {
        NSRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }
}

extension PrompterLayout {
    /// The open outline's bounding box in the canvas, top-left origin.
    var frameOfOpenShape: CGRect {
        let open = shape(open: true)
        return CGRect(x: (canvasSize.width - open.outerWidth) / 2, y: open.gap, width: open.outerWidth, height: open.height)
    }
}

/// The notch canvas: reports the pointer over the open prompter.
final class NotchCanvas: NSView {
    var onHover: ((Bool) -> Void)?
    var trackedRect: NSRect = .zero {
        didSet {
            if let area { removeTrackingArea(area) }
            let area = NSTrackingArea(rect: trackedRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
            addTrackingArea(area)
            self.area = area
        }
    }
    private var area: NSTrackingArea?

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

/// The prompter's springs: opening overshoots a little, like something with weight; closing settles without a bounce.
@MainActor
enum Motion {
    static func spring(open: Bool) -> CABasicAnimation {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let fade = CABasicAnimation()
            fade.duration = 0.2
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            return fade
        }
        let spring = open
            ? CASpringAnimation(perceptualDuration: 0.55, bounce: 0.2)
            : CASpringAnimation(perceptualDuration: 0.4, bounce: 0)
        spring.duration = spring.settlingDuration
        return spring
    }
}
