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

    func testMonthlyKeepsAnchorDayAcrossShortMonths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        var date = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
        var anchor: Int?
        var days: [Int] = []
        for _ in 0..<4 {
            anchor = BillingDateCalculator.resolvedAnchorDay(for: date, anchorDay: anchor, calendar: calendar)
            date = BillingDateCalculator.advance(from: date, cycle: .monthly, anchorDay: anchor, calendar: calendar)
            days.append(calendar.component(.day, from: date))
        }
        XCTAssertEqual(days, [29, 31, 30, 31])

        let back = BillingDateCalculator.rewind(from: date, cycle: .monthly, anchorDay: anchor, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: back), 30)
    }

    func testRewindRestoresMonthEnd() {
        let calendar = Calendar(identifier: .gregorian)
        let april30 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 30))!

        let previous = BillingDateCalculator.rewind(from: april30, cycle: .monthly, anchorDay: 31, calendar: calendar)

        XCTAssertEqual(previous, calendar.date(from: DateComponents(year: 2025, month: 3, day: 31))!)
    }

    func testStaleAnchorFollowsEditedDate() {
        let calendar = Calendar(identifier: .gregorian)
        let edited = calendar.date(from: DateComponents(year: 2025, month: 5, day: 15))!

        XCTAssertEqual(BillingDateCalculator.resolvedAnchorDay(for: edited, anchorDay: 31, calendar: calendar), 15)
    }

    func testYearlyLeapDay() {
        let calendar = Calendar(identifier: .gregorian)
        var date = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        for _ in 0..<4 {
            date = BillingDateCalculator.advance(from: date, cycle: .yearly, anchorDay: 29, calendar: calendar)
        }

        XCTAssertEqual(date, calendar.date(from: DateComponents(year: 2028, month: 2, day: 29))!)
    }
}
