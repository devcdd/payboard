import Foundation

public enum ReminderOption: Int, CaseIterable, Codable, Sendable {
    case threeDays = 3
    case oneDay = 1
    case sameDay = 0

    public var label: String {
        switch self {
        case .threeDays:
            return "3일 전"
        case .oneDay:
            return "1일 전"
        case .sameDay:
            return "당일"
        }
    }
}
