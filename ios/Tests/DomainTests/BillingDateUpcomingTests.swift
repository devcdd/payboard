import XCTest
@testable import Domain

final class BillingDateUpcomingTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testUpcoming() {
        let now = date(2026, 10, 19)
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 19, cycle: .monthly, from: now, calendar: calendar), date(2026, 10, 19))
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 25, cycle: .monthly, from: now, calendar: calendar), date(2026, 10, 25))
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 5, cycle: .monthly, from: now, calendar: calendar), date(2026, 11, 5))
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 31, cycle: .monthly, from: date(2027, 2, 10), calendar: calendar), date(2027, 2, 28))
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 1, month: 3, cycle: .yearly, from: now, calendar: calendar), date(2027, 3, 1))
        XCTAssertEqual(BillingDateCalculator.upcoming(day: 31, month: 12, cycle: .yearly, from: now, calendar: calendar), date(2026, 12, 31))
    }
}
