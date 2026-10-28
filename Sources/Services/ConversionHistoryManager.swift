import Foundation
import AppKit

public struct HistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let sourcePaths: [String]
    public let outputPaths: [String]
    public let targetFormat: String
    public let isSuccess: Bool
    public let errorMessage: String?
    public var isUndone: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourcePaths: [String],
        outputPaths: [String],
        targetFormat: String,
        isSuccess: Bool,
        errorMessage: String? = nil,
        isUndone: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourcePaths = sourcePaths
        self.outputPaths = outputPaths
        self.targetFormat = targetFormat
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.isUndone = isUndone
    }

    public var title: String {
        let firstSrc = sourcePaths.first.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? "Unknown"
        if sourcePaths.count > 1 {
            return "\(firstSrc) + \(sourcePaths.count - 1) more → \(targetFormat.uppercased())"
        }
        return "\(firstSrc) → \(targetFormat.uppercased())"
    }
}

@MainActor
public final class ConversionHistoryManager: ObservableObject {
    public static let shared = ConversionHistoryManager()

    @Published public private(set) var items: [HistoryItem] = []

    private let storageURL: URL

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tangerineDir = appSupport.appendingPathComponent("Tangerine", isDirectory: true)
        try? fm.createDirectory(at: tangerineDir, withIntermediateDirectories: true)
        self.storageURL = tangerineDir.appendingPathComponent("history.json")
        load()
    }

    public func record(sources: [URL], outputs: [URL], format: String, success: Bool, error: String? = nil) {
        let item = HistoryItem(
            sourcePaths: sources.map(\.path),
            outputPaths: outputs.map(\.path),
            targetFormat: format,
            isSuccess: success,
            errorMessage: error,
            isUndone: false
        )
        // Keep newest first, max 100 entries
        items.insert(item, at: 0)
        if items.count > 100 {
            items = Array(items.prefix(100))
        }
        save()
    }

    /// Moves generated output files to macOS Trash (matches Filee's Undo feature)
    public func undo(item: HistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }), !items[index].isUndone else { return }

        let fm = FileManager.default
        for path in item.outputPaths {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: path) {
                try? fm.trashItem(at: url, resultingItemURL: nil)
            }
        }

        items[index].isUndone = true
        save()
    }

    public func clearAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        self.items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL)
    }
}
