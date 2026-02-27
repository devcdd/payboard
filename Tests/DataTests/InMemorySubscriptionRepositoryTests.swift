import XCTest
@testable import Data
@testable import Domain

final class InMemorySubscriptionRepositoryTests: XCTestCase {
    func testUpcomingFiltersByDateWindow() async throws {
        let now = Date()
        let in2Days = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let in8Days = Calendar.current.date(byAdding: .day, value: 8, to: now)!

        let repository = InMemorySubscriptionRepository(seed: [
            Subscription(name: "Soon", category: .video, amount: 1000, billingCycle: .monthly, nextBillingDate: in2Days, iconKey: "preset_1"),
            Subscription(name: "Later", category: .video, amount: 1000, billingCycle: .monthly, nextBillingDate: in8Days, iconKey: "preset_2")
        ])

        let result = try await repository.upcoming(within: 7, from: now)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Soon")
    }

    func testDeleteRemovesSubscription() async throws {
        let item = Subscription(name: "A", category: .other, amount: 1, billingCycle: .monthly, nextBillingDate: .now, iconKey: "preset_1")
        let repository = InMemorySubscriptionRepository(seed: [item])

        try await repository.delete(id: item.id)
        let all = try await repository.fetchAll()

        XCTAssertTrue(all.isEmpty)
    }
}
