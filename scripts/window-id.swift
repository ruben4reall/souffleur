// scripts/window-id.swift <owner> [panel|window|all]: prints the ids of an app's windows on screen, with their bounds.
// "panel" is a window above the menu bar's level near the top of a screen (the notch prompter, growing out of the
// notch); "window" any other.
import CoreGraphics

let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Souffleur"
let kind = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "all"
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for window in list where (window["kCGWindowOwnerName"] as? String) == owner {
    let bounds = window["kCGWindowBounds"] as! [String: Double]
    let layer = window["kCGWindowLayer"] as? Int ?? 0
    let isPanel = bounds["Y"]! < 80 && layer > 0
    guard kind == "all" || (kind == "panel") == isPanel else { continue }
    print(window["kCGWindowNumber"]!, Int(bounds["X"]!), Int(bounds["Y"]!), Int(bounds["Width"]!), Int(bounds["Height"]!), layer, window["kCGWindowName"] as? String ?? "")
}
