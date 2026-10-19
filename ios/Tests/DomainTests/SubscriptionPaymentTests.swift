import XCTest
@testable import Domain

final class SubscriptionPaymentTests: XCTestCase {
    func testCompletedThroughRecordsMissedCycles() {
        let calendar = Calendar(identifier: .gregorian)
        let date = { (m: Int, d: Int) in calendar.date(from: DateComponents(year: 2026, month: m, day: d))! }
        let subscription = Subscription(name: "넷플릭스", category: .video, amount: 17000, billingCycle: .monthly, nextBillingDate: date(8, 19), iconKey: "icon_netflix")

        let paid = subscription.completedThrough(date(10, 18), calendar: calendar)

        XCTAssertEqual(paid.paymentHistoryDates, [date(8, 19), date(9, 19)])
        XCTAssertEqual(paid.lastPaymentDate, date(9, 19))
        XCTAssertEqual(paid.nextBillingDate, date(10, 19))
        XCTAssertEqual(subscription.completedThrough(date(8, 18), calendar: calendar), subscription)
    }
}
