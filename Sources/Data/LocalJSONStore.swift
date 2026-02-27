import Foundation
import Domain

actor LocalJSONStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "subscriptions.json") {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appURL = baseURL.appendingPathComponent("PayBoard", isDirectory: true)
        try? fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        self.fileURL = appURL.appendingPathComponent(fileName)

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [Subscription] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Subscription].self, from: data)
    }

    func save(_ subscriptions: [Subscription]) throws {
        let data = try encoder.encode(subscriptions)
        try data.write(to: fileURL, options: .atomic)
    }
}
