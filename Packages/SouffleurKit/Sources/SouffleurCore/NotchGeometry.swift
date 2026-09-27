import CoreGraphics

/// Where the camera housing sits at the top of a screen, in points.
public struct NotchMetrics: Equatable, Sendable {
    public var width: CGFloat
    public var height: CGFloat
    /// Horizontal centre of the notch, measured from the screen's left edge.
    public var centerX: CGFloat
    /// False when the screen has no notch and Souffleur draws the whole prompter itself.
    public var isHardware: Bool

    public init(width: CGFloat, height: CGFloat, centerX: CGFloat, isHardware: Bool) {
        self.width = width
        self.height = height
        self.centerX = centerX
        self.isHardware = isHardware
    }

    static let fallbackWidth: CGFloat = 180
    static let fallbackHeight: CGFloat = 24

    /// Reads the notch from what `NSScreen` reports: the safe area's top inset and the two menu bar areas that flank
    /// the camera. A screen without a notch gets a notch-sized space, centred in its menu bar.
    public static func resolve(
        screenWidth: CGFloat,
        safeAreaTop: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) -> NotchMetrics {
        if safeAreaTop > 0, let left = leftAreaWidth, let right = rightAreaWidth {
            let width = screenWidth - left - right
            if width > 0 {
                return NotchMetrics(width: width, height: safeAreaTop, centerX: left + width / 2, isHardware: true)
            }
        }
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackHeight
        return NotchMetrics(width: fallbackWidth, height: height, centerX: screenWidth / 2, isHardware: false)
    }
}

/// The prompter's outline: a body hanging from the top edge of the screen, with concave ears where it meets the
/// menu bar and rounded lower corners; or, below a menu bar without a notch, a floating slab rounded all round.
public struct PrompterShape: Equatable, Sendable {
    /// Width of the body, ears excluded.
    public var width: CGFloat
    public var height: CGFloat
    public var earRadius: CGFloat
    public var cornerRadius: CGFloat
    /// Distance below the top of the screen: zero hangs from the top edge, more floats.
    public var gap: CGFloat

    public init(width: CGFloat, height: CGFloat, earRadius: CGFloat, cornerRadius: CGFloat, gap: CGFloat = 0) {
        self.width = width
        self.height = height
        self.earRadius = earRadius
        self.cornerRadius = cornerRadius
        self.gap = gap
    }

    public var isFloating: Bool { gap > 0 }
    /// Width including both ears.
    public var outerWidth: CGFloat { isFloating ? width : width + earRadius * 2 }
}

/// Every size the notch prompter takes on one screen, in a top-left canvas big enough for all of them.
public struct PrompterLayout: Equatable, Sendable {
    public let notch: NotchMetrics
    /// Width of the open prompter.
    public let width: CGFloat
    /// Height of the text area below the camera.
    public let textHeight: CGFloat

    static let shadowMargin: CGFloat = 40
    static let floatingGap: CGFloat = 8

    public init(notch: NotchMetrics, width: CGFloat, textHeight: CGFloat) {
        self.notch = notch
        self.width = width
        self.textHeight = textHeight
    }

    public func shape(open: Bool) -> PrompterShape {
        if notch.isHardware {
            return open
                ? PrompterShape(width: max(width, notch.width + 150), height: notch.height + textHeight, earRadius: 12, cornerRadius: 26)
                : PrompterShape(width: notch.width, height: notch.height, earRadius: 4, cornerRadius: 9)
        }
        let gap = notch.height + Self.floatingGap
        return open
            ? PrompterShape(width: width, height: textHeight, earRadius: 0, cornerRadius: 26, gap: gap)
            : PrompterShape(width: notch.width, height: 30, earRadius: 0, cornerRadius: 15, gap: gap)
    }

    public var canvasSize: CGSize {
        let open = shape(open: true)
        return CGSize(width: open.outerWidth + Self.shadowMargin * 2, height: open.gap + open.height + Self.shadowMargin)
    }

    /// The text area of the open prompter in the canvas, top-left origin: below the camera, or the whole slab.
    public var textFrame: CGRect {
        let open = shape(open: true)
        let top = notch.isHardware ? notch.height : open.gap
        return CGRect(x: (canvasSize.width - open.width) / 2, y: top, width: open.width, height: textHeight)
    }

    /// The camera row of the open prompter, left and right of the notch, for the timer and the level meter.
    public var wingFrames: (left: CGRect, right: CGRect)? {
        guard notch.isHardware else { return nil }
        let open = shape(open: true)
        let bodyLeft = (canvasSize.width - open.width) / 2
        let side = (open.width - notch.width) / 2
        return (CGRect(x: bodyLeft, y: 0, width: side, height: notch.height),
                CGRect(x: bodyLeft + side + notch.width, y: 0, width: side, height: notch.height))
    }
}

public enum PrompterPath {
    /// The outline in a top-left space: the top edge lies on y = 0 (or `gap`) and the body is centred on `centerX`.
    /// Every shape is built from the same sequence of segments, so Core Animation can morph one into another. The
    /// lower corners ease into the straight edges (continuous curvature), softer than a circular arc.
    public static func make(_ shape: PrompterShape, centerX: CGFloat) -> CGPath {
        make(shape, centerX: centerX, closed: true)
    }

    /// The outline without its top edge when it hangs from the screen: the rim the glow runs along. A floating
    /// shape has no edge against the screen, so its rim is the whole outline.
    public static func rim(_ shape: PrompterShape, centerX: CGFloat) -> CGPath {
        make(shape, centerX: centerX, closed: shape.isFloating)
    }

    private static func make(_ shape: PrompterShape, centerX: CGFloat, closed: Bool) -> CGPath {
        let ear = shape.isFloating ? 0 : max(0, min(shape.earRadius, shape.height / 3))
        let left = centerX - shape.width / 2
        let right = centerX + shape.width / 2
        let top = shape.gap
        let bottom = shape.gap + shape.height
        let radius = min(shape.cornerRadius, shape.height / 2, shape.width / 2)
        let reach = max(0, min(radius * smoothing, bottom - top - ear, shape.width / 2))
        let handle = reach * handleRatio
        // Floating: the top corners are rounded like the bottom ones; attached: concave ears.
        let topReach = shape.isFloating ? reach : 0

        let path = CGMutablePath()
        if shape.isFloating {
            path.move(to: CGPoint(x: left + topReach, y: top))
            path.addQuadCurve(to: CGPoint(x: left, y: top + topReach), control: CGPoint(x: left, y: top))
        } else {
            path.move(to: CGPoint(x: left - ear, y: top))
            path.addQuadCurve(to: CGPoint(x: left, y: top + ear), control: CGPoint(x: left, y: top))
        }
        path.addLine(to: CGPoint(x: left, y: bottom - reach))
        path.addCurve(to: CGPoint(x: left + reach, y: bottom), control1: CGPoint(x: left, y: bottom - handle), control2: CGPoint(x: left + handle, y: bottom))
        path.addLine(to: CGPoint(x: right - reach, y: bottom))
        path.addCurve(to: CGPoint(x: right, y: bottom - reach), control1: CGPoint(x: right - handle, y: bottom), control2: CGPoint(x: right, y: bottom - handle))
        if shape.isFloating {
            path.addLine(to: CGPoint(x: right, y: top + topReach))
            path.addQuadCurve(to: CGPoint(x: right - topReach, y: top), control: CGPoint(x: right, y: top))
        } else {
            path.addLine(to: CGPoint(x: right, y: top + ear))
            path.addQuadCurve(to: CGPoint(x: right + ear, y: top), control: CGPoint(x: right, y: top))
        }
        if closed { path.closeSubpath() }
        return path
    }

    /// A continuous corner spreads over more of each edge than a circular arc of the same radius.
    static let smoothing: CGFloat = 1.28
    /// Distance of the Bézier handles from the corner, as a share of the reach. A circle would sit at 0.448.
    static let handleRatio: CGFloat = 0.36
}
