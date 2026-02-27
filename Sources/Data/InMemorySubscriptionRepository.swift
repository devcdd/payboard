import Foundation
import Domain

public actor InMemorySubscriptionRepository: SubscriptionRepository {
    private var storage: [Subscription]

    public init(seed: [Subscription] = []) {
        self.storage = seed
    }

    public func fetchAll() async throws -> [Subscription] {
        storage.sorted(by: { $0.nextBillingDate < $1.nextBillingDate })
    }

    public func create(_ subscription: Subscription) async throws {
        try subscription.validate()
        storage.append(subscription)
    }

    public func update(_ subscription: Subscription) async throws {
        guard let index = storage.firstIndex(where: { $0.id == subscription.id }) else {
            throw DomainError.notFound
        }
        storage[index] = subscription
    }

    public func delete(id: UUID) async throws {
        guard storage.contains(where: { $0.id == id }) else {
            throw DomainError.notFound
        }
        storage.removeAll(where: { $0.id == id })
    }

    public func upcoming(within days: Int, from now: Date) async throws -> [Subscription] {
        let future = Calendar.current.date(byAdding: .day, value: max(0, days), to: now) ?? now
        return storage.filter {
            ($0.nextBillingDate >= now) && ($0.nextBillingDate <= future)
        }
    }
}
