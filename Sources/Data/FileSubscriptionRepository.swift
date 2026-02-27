import Foundation
import Domain

public actor FileSubscriptionRepository: SubscriptionRepository {
    private let store: LocalJSONStore

    public init() {
        self.store = LocalJSONStore()
    }

    public func fetchAll() async throws -> [Subscription] {
        try await store.load()
            .filter(\.isActive)
            .sorted(by: { $0.nextBillingDate < $1.nextBillingDate })
    }

    public func create(_ subscription: Subscription) async throws {
        try subscription.validate()
        var current = try await store.load()
        current.append(subscription)
        try await store.save(current)
    }

    public func update(_ subscription: Subscription) async throws {
        try subscription.validate()
        var current = try await store.load()
        guard let index = current.firstIndex(where: { $0.id == subscription.id }) else {
            throw DomainError.notFound
        }
        current[index] = subscription
        try await store.save(current)
    }

    public func delete(id: UUID) async throws {
        var current = try await store.load()
        guard current.contains(where: { $0.id == id }) else {
            throw DomainError.notFound
        }
        current.removeAll(where: { $0.id == id })
        try await store.save(current)
    }

    public func upcoming(within days: Int, from now: Date = .now) async throws -> [Subscription] {
        let future = Calendar.current.date(byAdding: .day, value: max(0, days), to: now) ?? now
        return try await fetchAll().filter { subscription in
            (subscription.nextBillingDate >= now) && (subscription.nextBillingDate <= future)
        }
    }
}
