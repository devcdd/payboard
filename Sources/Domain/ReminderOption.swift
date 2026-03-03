import Foundation

public enum ReminderOption: Int, CaseIterable, Codable, Sendable {
    case threeDays = 3
    case oneDay = 1
    case sameDay = 0

    public var labelKey: String {
        switch self {
        case .threeDays:
            return "reminder.threeDays"
        case .oneDay:
            return "reminder.oneDay"
        case .sameDay:
            return "reminder.sameDay"
        }
    }
}
