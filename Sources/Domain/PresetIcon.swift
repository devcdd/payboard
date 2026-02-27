import Foundation

public struct PresetIcon: Identifiable, Codable, Equatable, Sendable {
    public var id: String { key }
    public let key: String
    public let displayName: String
    public let systemSymbol: String

    public init(key: String, displayName: String, systemSymbol: String) {
        self.key = key
        self.displayName = displayName
        self.systemSymbol = systemSymbol
    }
}
