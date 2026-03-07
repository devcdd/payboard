import Foundation

public enum BillingDateCalculator {
    public static func advance(from date: Date, cycle: BillingCycle, calendar: Calendar = .current) -> Date {
        switch cycle {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case let .customDays(days):
            return calendar.date(byAdding: .day, value: max(1, days), to: date) ?? date
        }
    }
}
