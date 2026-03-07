import Foundation

public struct PresetIcon: Identifiable, Codable, Equatable, Sendable {
    public var id: String { key }
    public let key: String
    public let displayName: String
    public let displayNameKey: String?
    public let systemSymbol: String
    public let assetName: String?
    public let aliases: [String]

    public init(
        key: String,
        displayName: String,
        displayNameKey: String? = nil,
        systemSymbol: String,
        assetName: String? = nil,
        aliases: [String] = []
    ) {
        self.key = key
        self.displayName = displayName
        self.displayNameKey = displayNameKey
        self.systemSymbol = systemSymbol
        self.assetName = assetName
        self.aliases = aliases
    }
}
