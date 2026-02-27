import Foundation
import Domain

public enum SampleData {
    public static let subscriptions: [Subscription] = [
        Subscription(
            name: "Netflix",
            category: .video,
            amount: 17_000,
            currencyCode: "KRW",
            billingCycle: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now,
            iconKey: "netflix"
        ),
        Subscription(
            name: "Spotify",
            category: .music,
            amount: 10_900,
            currencyCode: "KRW",
            billingCycle: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 8, to: .now) ?? .now,
            iconKey: "spotify"
        ),
        Subscription(
            name: "iCloud+",
            category: .cloud,
            amount: 4_400,
            currencyCode: "KRW",
            billingCycle: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now,
            iconKey: "icloud"
        )
    ]
}
