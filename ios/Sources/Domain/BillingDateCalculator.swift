import Foundation

public enum BillingDateCalculator {
    public static func advance(from date: Date, cycle: BillingCycle, anchorDay: Int? = nil, calendar: Calendar = .current) -> Date {
        shift(date, cycles: 1, cycle: cycle, anchorDay: anchorDay, calendar: calendar)
    }

    public static func rewind(from date: Date, cycle: BillingCycle, anchorDay: Int? = nil, calendar: Calendar = .current) -> Date {
        shift(date, cycles: -1, cycle: cycle, anchorDay: anchorDay, calendar: calendar)
    }

    /// 월말 보정(31일 → 2월 28일)으로 줄어든 날짜에서도 원래 결제 일자를 돌려준다.
    /// 저장된 기준일이 날짜와 맞지 않으면(사용자가 날짜를 직접 바꾼 경우) 날짜의 일자를 따른다.
    public static func resolvedAnchorDay(for date: Date, anchorDay: Int?, calendar: Calendar = .current) -> Int {
        let day = calendar.component(.day, from: date)
        guard let anchorDay, (1...31).contains(anchorDay) else { return day }
        let length = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        return min(anchorDay, length) == day ? anchorDay : day
    }

    private static func shift(_ date: Date, cycles: Int, cycle: BillingCycle, anchorDay: Int?, calendar: Calendar) -> Date {
        switch cycle {
        case .monthly:
            return shiftMonths(date, by: cycles, anchorDay: anchorDay, calendar: calendar)
        case .yearly:
            return shiftMonths(date, by: cycles * 12, anchorDay: anchorDay, calendar: calendar)
        case let .customDays(days):
            return calendar.date(byAdding: .day, value: cycles * max(1, days), to: date) ?? date
        }
    }

    private static func shiftMonths(_ date: Date, by months: Int, anchorDay: Int?, calendar: Calendar) -> Date {
        let anchor = resolvedAnchorDay(for: date, anchorDay: anchorDay, calendar: calendar)
        guard let moved = calendar.date(byAdding: .month, value: months, to: date),
              let length = calendar.range(of: .day, in: .month, for: moved)?.count else {
            return date
        }
        var components = calendar.dateComponents([.era, .year, .month, .hour, .minute, .second, .nanosecond], from: moved)
        components.day = min(anchor, length)
        return calendar.date(from: components) ?? moved
    }
}
