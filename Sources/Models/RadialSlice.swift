import Foundation

public struct RadialSlice: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let iconName: String?
    public let actionKind: SliceActionKind

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        actionKind: SliceActionKind
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.actionKind = actionKind
    }
}

public enum SliceActionKind: Equatable, Sendable {
    case convert(targetExtension: String)
    case tool(toolName: String)
    case fileAction(actionType: FileActionType)
}

public enum FileActionType: String, Equatable, Sendable {
    case airdrop = "AirDrop"
    case float = "Float"
    case copy = "Copy"
    case move = "Move"
    case copyPath = "Copy Path"
    case terminal = "Terminal"
}

public extension RadialSlice {
    static func slices(for category: FileCategory, mode: WheelMode, currentExtension: String = "") -> [RadialSlice] {
        let currentExt = currentExtension.lowercased()

        switch mode {
        case .convert:
            return convertSlices(for: category, excluding: currentExt)
        case .tools:
            return toolSlices(for: category)
        case .actions:
            return actionSlices()
        }
    }

    private static func convertSlices(for category: FileCategory, excluding ext: String) -> [RadialSlice] {
        let formats = ConversionMatrix.validTargets(for: category, currentExtension: ext)

        return formats.map { fmt in
            RadialSlice(
                id: "convert_\(fmt)",
                title: fmt,
                subtitle: "Convert to \(fmt)",
                iconName: nil,
                actionKind: .convert(targetExtension: fmt.lowercased())
            )
        }
    }

    private static func toolSlices(for category: FileCategory) -> [RadialSlice] {
        switch category {
        case .image:
            return [
                RadialSlice(id: "tool_compress", title: "COMPRESS", iconName: "arrow.down.right.and.arrow.up.left", actionKind: .tool(toolName: "compress")),
                RadialSlice(id: "tool_metadata", title: "METADATA", iconName: "tag", actionKind: .tool(toolName: "metadata")),
                RadialSlice(id: "tool_edit", title: "EDIT", iconName: "slider.horizontal.3", actionKind: .tool(toolName: "edit")),
                RadialSlice(id: "tool_annotate", title: "ANNOTATE", iconName: "pencil.tip", actionKind: .tool(toolName: "annotate")),
                RadialSlice(id: "tool_addbg", title: "ADD BG", iconName: "photo.artframe", actionKind: .tool(toolName: "addbg")),
                RadialSlice(id: "tool_crop", title: "CROP", iconName: "crop", actionKind: .tool(toolName: "crop")),
                RadialSlice(id: "tool_redact", title: "REDACT", iconName: "eye.slash", actionKind: .tool(toolName: "redact"))
            ]

        case .video:
            return [
                RadialSlice(id: "tool_compress", title: "COMPRESS", iconName: "arrow.down.right.and.arrow.up.left", actionKind: .tool(toolName: "compress")),
                RadialSlice(id: "tool_metadata", title: "METADATA", iconName: "info.circle", actionKind: .tool(toolName: "metadata")),
                RadialSlice(id: "tool_mute", title: "MUTE", iconName: "speaker.slash", actionKind: .tool(toolName: "mute")),
                RadialSlice(id: "tool_trim", title: "TRIM", iconName: "scissors", actionKind: .tool(toolName: "trim")),
                RadialSlice(id: "tool_crop", title: "CROP", iconName: "crop", actionKind: .tool(toolName: "crop")),
                RadialSlice(id: "tool_speed", title: "SPEED", iconName: "gauge.with.needle", actionKind: .tool(toolName: "speed")),
                RadialSlice(id: "tool_snapshot", title: "SNAPSHOT", iconName: "camera", actionKind: .tool(toolName: "snapshot")),
                RadialSlice(id: "tool_split", title: "SPLIT", iconName: "film", actionKind: .tool(toolName: "split")),
                RadialSlice(id: "tool_redact", title: "REDACT", iconName: "eye.slash", actionKind: .tool(toolName: "redact"))
            ]

        case .audio:
            return [
                RadialSlice(id: "tool_compress", title: "COMPRESS", iconName: "arrow.down.right.and.arrow.up.left", actionKind: .tool(toolName: "compress")),
                RadialSlice(id: "tool_metadata", title: "METADATA", iconName: "info.circle", actionKind: .tool(toolName: "metadata")),
                RadialSlice(id: "tool_normalize", title: "NORMALIZE", iconName: "waveform", actionKind: .tool(toolName: "normalize")),
                RadialSlice(id: "tool_visualize", title: "VISUALIZE", iconName: "chart.bar.xaxis", actionKind: .tool(toolName: "visualize")),
                RadialSlice(id: "tool_trim", title: "TRIM", iconName: "scissors", actionKind: .tool(toolName: "trim")),
                RadialSlice(id: "tool_channels", title: "CHANNELS", iconName: "slider.vertical.3", actionKind: .tool(toolName: "channels")),
                RadialSlice(id: "tool_bleep", title: "BLEEP", iconName: "waveform.path.ecg", actionKind: .tool(toolName: "bleep"))
            ]

        case .pdf:
            return [
                RadialSlice(id: "tool_compress", title: "COMPRESS", iconName: "arrow.down.right.and.arrow.up.left", actionKind: .tool(toolName: "compress")),
                RadialSlice(id: "tool_metadata", title: "METADATA", iconName: "info.circle", actionKind: .tool(toolName: "metadata")),
                RadialSlice(id: "tool_split", title: "SPLIT", iconName: "rectangle.split.2x1", actionKind: .tool(toolName: "split")),
                RadialSlice(id: "tool_organize", title: "ORGANIZE", iconName: "square.grid.2x2", actionKind: .tool(toolName: "organize"))
            ]

        case .archive:
            return [
                RadialSlice(id: "tool_extract", title: "EXTRACT", subtitle: "Extract Archive", iconName: "shippingbox.and.arrow.backward", actionKind: .tool(toolName: "extract"))
            ]

        default:
            return [
                RadialSlice(id: "tool_compress", title: "COMPRESS", iconName: "arrow.down.right.and.arrow.up.left", actionKind: .tool(toolName: "compress")),
                RadialSlice(id: "tool_metadata", title: "METADATA", iconName: "info.circle", actionKind: .tool(toolName: "metadata"))
            ]
        }
    }

    private static func actionSlices() -> [RadialSlice] {
        return [
            RadialSlice(id: "action_airdrop", title: "AIRDROP", subtitle: "AirDrop", iconName: "antenna.radiowaves.left.and.right", actionKind: .fileAction(actionType: .airdrop)),
            RadialSlice(id: "action_float", title: "FLOAT", subtitle: "Float", iconName: "pin", actionKind: .fileAction(actionType: .float)),
            RadialSlice(id: "action_copy", title: "COPY", subtitle: "Copy", iconName: "doc.on.doc", actionKind: .fileAction(actionType: .copy)),
            RadialSlice(id: "action_move", title: "MOVE", subtitle: "Move", iconName: "arrow.right.to.line.compact", actionKind: .fileAction(actionType: .move)),
            RadialSlice(id: "action_copypath", title: "COPY PATH", subtitle: "Copy Path", iconName: "doc.text", actionKind: .fileAction(actionType: .copyPath)),
            RadialSlice(id: "action_terminal", title: "TERMINAL", subtitle: "Terminal", iconName: "terminal", actionKind: .fileAction(actionType: .terminal))
        ]
    }
}
