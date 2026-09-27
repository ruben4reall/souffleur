import AppKit
import SwiftUI

/// Souffleur's design tokens. The prompter is black like the notch it hangs from; one accent, Lamp, the warm light
/// of a prompter's box, marks what belongs to Souffleur: the place in the script, the live level, the main button.
public enum Theme {
    public static let lamp = Color(red: 1, green: 0.706, blue: 0.278)
    public static let lampNS = NSColor(srgbRed: 1, green: 0.706, blue: 0.278, alpha: 1)
    /// The deeper amber of gradients and pressed states.
    public static let ember = Color(red: 0.941, green: 0.541, blue: 0.141)
    public static let stage = Color(red: 0.027, green: 0.027, blue: 0.031)

    // The system's label colours on a dark background.
    static let secondaryText = Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.6)
    static let tertiaryText = Color(red: 0.92, green: 0.92, blue: 0.96).opacity(0.32)
    static let fill = Color.white.opacity(0.1)
    static let raisedFill = Color.white.opacity(0.16)

    /// Colours of the prompter's text for each theme.
    struct Palette {
        let background: NSColor
        let text: NSColor
        let read: NSColor
        let heading: NSColor
        let cue: NSColor
        let band: NSColor
    }

    static func palette(_ theme: PrompterTheme) -> Palette {
        switch theme {
        case .night:
            Palette(background: .black, text: NSColor(white: 0.97, alpha: 1), read: NSColor(white: 0.97, alpha: 0.34),
                    heading: NSColor(white: 0.97, alpha: 0.5), cue: lampNS.withAlphaComponent(0.85), band: NSColor(white: 1, alpha: 0.06))
        case .paper:
            Palette(background: NSColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1), text: NSColor(white: 0.08, alpha: 1),
                    read: NSColor(white: 0.08, alpha: 0.3), heading: NSColor(white: 0.08, alpha: 0.5),
                    cue: NSColor(srgbRed: 0.78, green: 0.42, blue: 0.05, alpha: 1), band: NSColor(white: 0, alpha: 0.05))
        case .contrast:
            Palette(background: .black, text: NSColor(srgbRed: 1, green: 0.93, blue: 0.2, alpha: 1), read: NSColor(white: 1, alpha: 0.4),
                    heading: NSColor(white: 1, alpha: 0.7), cue: NSColor(srgbRed: 0.35, green: 0.85, blue: 1, alpha: 1), band: NSColor(white: 1, alpha: 0.1))
        }
    }

    enum Font {
        static let caption = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let figure = SwiftUI.Font.system(size: 11, weight: .medium).monospacedDigit()
    }
}
