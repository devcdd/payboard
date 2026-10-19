import Foundation

public extension BillingDateCalculator {
    /// 오늘(포함) 이후 처음 돌아오는 결제일. month 는 연간 결제에서만 쓴다.
    static func upcoming(day: Int, month: Int? = nil, cycle: BillingCycle, from now: Date = .now, calendar: Calendar = .current) -> Date {
        let day = min(max(day, 1), 31)
        let today = calendar.startOfDay(for: now)
        var components = calendar.dateComponents([.year, .month], from: today)
        if case .yearly = cycle, let month, (1...12).contains(month) {
            components.month = month
        }
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let length = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else {
            return today
        }
        components.day = min(day, length)
        let candidate = calendar.date(from: components) ?? today
        return candidate < today ? advance(from: candidate, cycle: cycle, anchorDay: day, calendar: calendar) : candidate
    }
}
