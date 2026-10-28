import Foundation

public enum WheelMode: String, CaseIterable, Identifiable, Sendable {
    case convert = "Convert Formats"
    case tools = "File Tools"
    case actions = "File Actions"

    public var id: String { rawValue }

    public var defaultKeyName: String {
        switch self {
        case .convert: return "shift"
        case .tools: return "command"
        case .actions: return "control"
        }
    }

    public var defaultModifierSymbol: String {
        switch self {
        case .convert: return "⇧"
        case .tools: return "⌘"
        case .actions: return "⌃"
        }
    }
}
