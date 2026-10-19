import Foundation

public extension Subscription {
    /// 이번 회차를 date 에 결제한 것으로 기록하고 다음 결제일로 넘긴다.
    func completed(at date: Date) -> Subscription {
        var copy = self
        copy.lastPaymentDate = date
        copy.paymentHistoryDates = (paymentHistoryDates + [date]).sorted(by: <)
        copy.billingAnchorDay = BillingDateCalculator.resolvedAnchorDay(for: nextBillingDate, anchorDay: billingAnchorDay)
        copy.nextBillingDate = BillingDateCalculator.advance(from: nextBillingDate, cycle: billingCycle, anchorDay: copy.billingAnchorDay)
        copy.updatedAt = date
        return copy
    }

    /// day(포함)까지 밀린 회차를 모두 원래 결제일로 기록하며 그 이후까지 넘긴다.
    func completedThrough(_ day: Date, calendar: Calendar = .current) -> Subscription {
        let day = calendar.startOfDay(for: day)
        var copy = self
        while calendar.startOfDay(for: copy.nextBillingDate) <= day {
            let advanced = copy.completed(at: copy.nextBillingDate)
            guard advanced.nextBillingDate > copy.nextBillingDate else { break }
            copy = advanced
        }
        return copy
    }
}
