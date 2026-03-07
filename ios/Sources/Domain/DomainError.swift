import Foundation

public enum DomainError: Error, LocalizedError, Sendable {
    case validation(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case let .validation(message):
            return message
        case .notFound:
            return "Item not found."
        }
    }
}
