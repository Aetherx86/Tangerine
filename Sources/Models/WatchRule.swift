import Foundation

public struct WatchRule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var folderPath: String
    public var targetFormat: String
    public var moveOriginals: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        folderPath: String,
        targetFormat: String,
        moveOriginals: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.folderPath = folderPath
        self.targetFormat = targetFormat
        self.moveOriginals = moveOriginals
        self.isEnabled = isEnabled
    }
}
