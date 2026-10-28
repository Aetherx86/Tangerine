import Foundation
import SwiftUI
import Combine

public enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case coloredTangerine = "Vibrant Orange"
    case monochromeTemplate = "Monochrome Template"

    public var id: String { rawValue }
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    @AppStorage("convertModifierKey") public var convertModifierKey: String = "shift"
    @AppStorage("toolsModifierKey") public var toolsModifierKey: String = "command"
    @AppStorage("actionsModifierKey") public var actionsModifierKey: String = "control"
    
    @AppStorage("menuBarIconStyle") public var menuBarIconStyleRaw: String = MenuBarIconStyle.coloredTangerine.rawValue
    @AppStorage("playSounds") public var playSounds: Bool = true
    @AppStorage("hapticFeedback") public var hapticFeedback: Bool = true
    @AppStorage("revealInFinder") public var revealInFinder: Bool = true
    @AppStorage("saveBesideOriginal") public var saveBesideOriginal: Bool = true
    @AppStorage("customOutputDirectory") public var customOutputDirectory: String = ""
    @AppStorage("jpegQuality") public var jpegQuality: Double = 0.88
    @AppStorage("pdfDPI") public var pdfDPI: Double = 300.0

    public var menuBarIconStyle: MenuBarIconStyle {
        get { MenuBarIconStyle(rawValue: menuBarIconStyleRaw) ?? .coloredTangerine }
        set { menuBarIconStyleRaw = newValue.rawValue }
    }

    private init() {}
}
