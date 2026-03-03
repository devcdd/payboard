import Foundation

public enum SubscriptionCategory: String, CaseIterable, Codable, Sendable {
    case video
    case music
    case productivity
    case cloud
    case housing
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
    public var isAmountUndecided: Bool
    public var currencyCode: String
    public var billingCycle: BillingCycle
    public var nextBillingDate: Date
    public var lastPaymentDate: Date?
    public var iconKey: String
    public var iconColorKey: String
    public var customCategoryName: String?
    public var notificationsEnabled: Bool
    public var isActive: Bool
    public var memo: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        category: SubscriptionCategory,
        amount: Decimal,
        isAmountUndecided: Bool = false,
        currencyCode: String = "KRW",
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        lastPaymentDate: Date? = nil,
        iconKey: String,
        iconColorKey: String = "blue",
        customCategoryName: String? = nil,
        notificationsEnabled: Bool = true,
        isActive: Bool = true,
        memo: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.amount = amount
        self.isAmountUndecided = isAmountUndecided
        self.currencyCode = currencyCode
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.lastPaymentDate = lastPaymentDate
        self.iconKey = iconKey
        self.iconColorKey = iconColorKey
        self.customCategoryName = customCategoryName
        self.notificationsEnabled = notificationsEnabled
        self.isActive = isActive
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension Subscription {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case amount
        case isAmountUndecided
        case currencyCode
        case billingCycle
        case nextBillingDate
        case lastPaymentDate
        case iconKey
        case iconColorKey
        case customCategoryName
        case notificationsEnabled
        case isActive
        case memo
        case createdAt
        case updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            category: try container.decode(SubscriptionCategory.self, forKey: .category),
            amount: try container.decode(Decimal.self, forKey: .amount),
            isAmountUndecided: try container.decodeIfPresent(Bool.self, forKey: .isAmountUndecided) ?? false,
            currencyCode: try container.decode(String.self, forKey: .currencyCode),
            billingCycle: try container.decode(BillingCycle.self, forKey: .billingCycle),
            nextBillingDate: try container.decode(Date.self, forKey: .nextBillingDate),
            lastPaymentDate: try container.decodeIfPresent(Date.self, forKey: .lastPaymentDate),
            iconKey: try container.decode(String.self, forKey: .iconKey),
            iconColorKey: try container.decodeIfPresent(String.self, forKey: .iconColorKey) ?? "blue",
            customCategoryName: try container.decodeIfPresent(String.self, forKey: .customCategoryName),
            notificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true,
            isActive: try container.decode(Bool.self, forKey: .isActive),
            memo: try container.decodeIfPresent(String.self, forKey: .memo),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }
}

public extension Subscription {
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainError.validation("Name is required.")
        }
        guard isAmountUndecided || amount > 0 else {
            throw DomainError.validation("Amount must be greater than 0.")
        }
    }
}

public extension SubscriptionCategory {
    var labelKey: String {
        switch self {
        case .video:
            return "category.video"
        case .music:
            return "category.music"
        case .productivity:
            return "category.productivity"
        case .cloud:
            return "category.cloud"
        case .housing:
            return "category.housing"
        case .shopping:
            return "category.shopping"
        case .gaming:
            return "category.gaming"
        case .finance:
            return "category.finance"
        case .education:
            return "category.education"
        case .health:
            return "category.health"
        case .other:
            return "category.other"
        }
    }
}
