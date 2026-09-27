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

/// The prompter's outline: a body hanging from the top edge of the screen, or from the bottom of the menu bar on a
/// screen without a notch, with concave ears where it meets what it hangs from and rounded lower corners.
public struct PrompterShape: Equatable, Sendable {
    /// Width of the body, ears excluded.
    public var width: CGFloat
    public var height: CGFloat
    public var earRadius: CGFloat
    public var cornerRadius: CGFloat
    /// Distance of the top edge below the top of the screen: zero under a notch, the menu bar's height elsewhere.
    public var top: CGFloat

    public init(width: CGFloat, height: CGFloat, earRadius: CGFloat, cornerRadius: CGFloat, top: CGFloat = 0) {
        self.width = width
        self.height = height
        self.earRadius = earRadius
        self.cornerRadius = cornerRadius
        self.top = top
    }

    /// Width including both ears.
    public var outerWidth: CGFloat { width + earRadius * 2 }
}

/// Every size the notch prompter takes on one screen, in a top-left canvas big enough for all of them.
public struct PrompterLayout: Equatable, Sendable {
    public let notch: NotchMetrics
    /// Width of the open prompter.
    public let width: CGFloat
    /// Height of the text area below the camera.
    public let textHeight: CGFloat

    /// Room around the open prompter for the halo of light beneath it.
    static let shadowMargin: CGFloat = 24
    /// The classic notch prompter's proportions: ears of 25 points and lower corners of 13 on a body 400 points wide.
    static let earRatio: CGFloat = 25 / 400
    static let cornerRatio: CGFloat = 13 / 400

    public init(notch: NotchMetrics, width: CGFloat, textHeight: CGFloat) {
        self.notch = notch
        self.width = width
        self.textHeight = textHeight
    }

    /// Under a notch the prompter grows out of the camera housing; elsewhere it drops from the menu bar.
    public func shape(open: Bool) -> PrompterShape {
        let top = notch.isHardware ? 0 : notch.height
        guard open else {
            return notch.isHardware
                ? PrompterShape(width: notch.width, height: notch.height, earRadius: 4, cornerRadius: 9)
                : PrompterShape(width: notch.width, height: 6, earRadius: 2, cornerRadius: 3, top: top)
        }
        let body = notch.isHardware ? max(width, notch.width + 150) : width
        let height = (notch.isHardware ? notch.height : 0) + textHeight
        return PrompterShape(width: body, height: height, earRadius: body * Self.earRatio, cornerRadius: body * Self.cornerRatio, top: top)
    }

    public var canvasSize: CGSize {
        let open = shape(open: true)
        return CGSize(width: open.outerWidth + Self.shadowMargin * 2, height: open.top + open.height + Self.shadowMargin)
    }

    /// The text area of the open prompter in the canvas, top-left origin: below the camera, or below the menu bar.
    public var textFrame: CGRect {
        let open = shape(open: true)
        return CGRect(x: (canvasSize.width - open.width) / 2, y: notch.height, width: open.width, height: textHeight)
    }

    /// The body of the open prompter, ears excluded, in the canvas, top-left origin.
    public var bodyFrame: CGRect {
        let open = shape(open: true)
        return CGRect(x: (canvasSize.width - open.width) / 2, y: open.top, width: open.width, height: open.height)
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
    /// The outline in a top-left space: the top edge lies on y = `top` and the body is centred on `centerX`. Every
    /// shape is built from the same sequence of segments, so Core Animation can morph one into another. The lower
    /// corners ease into the straight edges (continuous curvature), softer than a circular arc.
    public static func make(_ shape: PrompterShape, centerX: CGFloat) -> CGPath {
        let ear = max(0, min(shape.earRadius, shape.height / 3))
        let left = centerX - shape.width / 2
        let right = centerX + shape.width / 2
        let top = shape.top
        let bottom = shape.top + shape.height
        let radius = min(shape.cornerRadius, shape.height / 2, shape.width / 2)
        let reach = max(0, min(radius * smoothing, bottom - top - ear, shape.width / 2))
        let handle = reach * handleRatio

        let path = CGMutablePath()
        path.move(to: CGPoint(x: left - ear, y: top))
        path.addQuadCurve(to: CGPoint(x: left, y: top + ear), control: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: left, y: bottom - reach))
        path.addCurve(to: CGPoint(x: left + reach, y: bottom), control1: CGPoint(x: left, y: bottom - handle), control2: CGPoint(x: left + handle, y: bottom))
        path.addLine(to: CGPoint(x: right - reach, y: bottom))
        path.addCurve(to: CGPoint(x: right, y: bottom - reach), control1: CGPoint(x: right - handle, y: bottom), control2: CGPoint(x: right, y: bottom - handle))
        path.addLine(to: CGPoint(x: right, y: top + ear))
        path.addQuadCurve(to: CGPoint(x: right + ear, y: top), control: CGPoint(x: right, y: top))
        path.closeSubpath()
        return path
    }

    /// A continuous corner spreads over more of each edge than a circular arc of the same radius.
    static let smoothing: CGFloat = 1.28
    /// Distance of the Bézier handles from the corner, as a share of the reach. A circle would sit at 0.448.
    static let handleRatio: CGFloat = 0.36
}
