import XCTest
@testable import Domain

final class SubscriptionValidationTests: XCTestCase {
    func testValidationRejectsZeroAmount() {
        let sub = Subscription(
            name: "Invalid",
            category: .other,
            amount: 0,
            billingCycle: .monthly,
            nextBillingDate: .now,
            iconKey: "preset_1"
        )

        XCTAssertThrowsError(try sub.validate())
    }

    func testValidationAcceptsValidPayload() {
        let sub = Subscription(
            name: "Valid",
            category: .other,
            amount: 1000,
            billingCycle: .monthly,
            nextBillingDate: .now,
            iconKey: "preset_1"
        )

        XCTAssertNoThrow(try sub.validate())
    }
}
