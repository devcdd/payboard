import XCTest
@testable import Domain

final class BillingDateCalculatorTests: XCTestCase {
    func testAdvanceMonthly() {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!

        let next = BillingDateCalculator.advance(from: base, cycle: .monthly, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!

        XCTAssertEqual(next, expected)
    }

    func testAdvanceCustomDays() {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: DateComponents(year: 2025, month: 12, day: 30))!

        let next = BillingDateCalculator.advance(from: base, cycle: .customDays(5), calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!

        XCTAssertEqual(next, expected)
    }
}
