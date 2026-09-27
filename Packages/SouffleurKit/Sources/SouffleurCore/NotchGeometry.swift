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

/// The prompter's outline: a body hanging from a straight top edge, with concave ears where it meets what it hangs
/// from and rounded lower corners.
public struct PrompterShape: Equatable, Sendable {
    /// Width of the body, ears excluded.
    public var width: CGFloat
    public var height: CGFloat
    public var earRadius: CGFloat
    public var cornerRadius: CGFloat

    public init(width: CGFloat, height: CGFloat, earRadius: CGFloat, cornerRadius: CGFloat) {
        self.width = width
        self.height = height
        self.earRadius = earRadius
        self.cornerRadius = cornerRadius
    }

    /// Width including both ears.
    public var outerWidth: CGFloat { width + earRadius * 2 }
}

/// Every size the notch prompter takes on one screen, in a top-left canvas big enough for all of them. The canvas
/// starts at the prompter's top edge, which hangs `hangY` points below the top of the screen.
public struct PrompterLayout: Equatable, Sendable {
    public let notch: NotchMetrics
    /// Width of the open prompter.
    public let width: CGFloat
    /// Height of the text area.
    public let textHeight: CGFloat

    /// The band at the top of the prompter that holds the timer and the voice.
    public static let statusHeight: CGFloat = 22
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

    /// Where the prompter hangs, in points below the top of the screen: from the notch's lower edge, or from the
    /// menu bar on a screen without one. The menu bar stays free: its items, and whatever other apps show beside
    /// the camera, are never covered.
    public var hangY: CGFloat { notch.height }

    /// Closed, a sliver under the notch; open, the prompter, always a little wider than the notch.
    public func shape(open: Bool) -> PrompterShape {
        guard open else { return PrompterShape(width: notch.width, height: 6, earRadius: 2, cornerRadius: 3) }
        let body = max(width, notch.width + 60)
        return PrompterShape(width: body, height: Self.statusHeight + textHeight, earRadius: body * Self.earRatio, cornerRadius: body * Self.cornerRatio)
    }

    public var canvasSize: CGSize {
        let open = shape(open: true)
        return CGSize(width: open.outerWidth + Self.shadowMargin * 2, height: open.height + Self.shadowMargin)
    }

    /// The body of the open prompter, ears excluded, in the canvas, top-left origin.
    public var bodyFrame: CGRect {
        let open = shape(open: true)
        return CGRect(x: (canvasSize.width - open.width) / 2, y: 0, width: open.width, height: open.height)
    }

    /// The band for the timer and the voice, at the top of the body.
    public var statusFrame: CGRect {
        CGRect(x: bodyFrame.minX, y: 0, width: bodyFrame.width, height: Self.statusHeight)
    }

    /// The text area, below the band.
    public var textFrame: CGRect {
        CGRect(x: bodyFrame.minX, y: Self.statusHeight, width: bodyFrame.width, height: textHeight)
    }
}

public enum PrompterPath {
    /// The outline in a top-left space: the top edge lies on y = 0 and the body is centred on `centerX`. Every shape
    /// is built from the same sequence of segments, so Core Animation can morph one into another. The lower corners
    /// ease into the straight edges (continuous curvature), softer than a circular arc.
    public static func make(_ shape: PrompterShape, centerX: CGFloat) -> CGPath {
        let ear = max(0, min(shape.earRadius, shape.height / 3))
        let left = centerX - shape.width / 2
        let right = centerX + shape.width / 2
        let bottom = shape.height
        let radius = min(shape.cornerRadius, shape.height / 2, shape.width / 2)
        let reach = max(0, min(radius * smoothing, bottom - ear, shape.width / 2))
        let handle = reach * handleRatio

        let path = CGMutablePath()
        path.move(to: CGPoint(x: left - ear, y: 0))
        path.addQuadCurve(to: CGPoint(x: left, y: ear), control: CGPoint(x: left, y: 0))
        path.addLine(to: CGPoint(x: left, y: bottom - reach))
        path.addCurve(to: CGPoint(x: left + reach, y: bottom), control1: CGPoint(x: left, y: bottom - handle), control2: CGPoint(x: left + handle, y: bottom))
        path.addLine(to: CGPoint(x: right - reach, y: bottom))
        path.addCurve(to: CGPoint(x: right, y: bottom - reach), control1: CGPoint(x: right - handle, y: bottom), control2: CGPoint(x: right, y: bottom - handle))
        path.addLine(to: CGPoint(x: right, y: ear))
        path.addQuadCurve(to: CGPoint(x: right + ear, y: 0), control: CGPoint(x: right, y: 0))
        path.closeSubpath()
        return path
    }

    /// A continuous corner spreads over more of each edge than a circular arc of the same radius.
    static let smoothing: CGFloat = 1.28
    /// Distance of the Bézier handles from the corner, as a share of the reach. A circle would sit at 0.448.
    static let handleRatio: CGFloat = 0.36
}
