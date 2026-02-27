import Foundation

public enum SubscriptionCategory: String, CaseIterable, Codable, Sendable {
    case video
    case music
    case productivity
    case cloud
    case shopping
    case gaming
    case finance
    case education
    case health
    case other
}

public enum BillingCycle: Codable, Equatable, Hashable, Sendable {
    case monthly
    case yearly
    case customDays(Int)

    public var dayInterval: Int {
        switch self {
        case .monthly:
            return 30
        case .yearly:
            return 365
        case let .customDays(days):
            return max(1, days)
        }
    }
}

public struct Subscription: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var category: SubscriptionCategory
    public var amount: Decimal
    public var currencyCode: String
    public var billingCycle: BillingCycle
    public var nextBillingDate: Date
    public var iconKey: String
    public var isActive: Bool
    public var memo: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        category: SubscriptionCategory,
        amount: Decimal,
        currencyCode: String = "KRW",
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        iconKey: String,
        isActive: Bool = true,
        memo: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.amount = amount
        self.currencyCode = currencyCode
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.iconKey = iconKey
        self.isActive = isActive
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension Subscription {
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validation("Name is required.")
        }
        guard amount > 0 else {
            throw DomainError.validation("Amount must be greater than 0.")
        }
    }
}
