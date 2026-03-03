import Foundation
import Domain
import Data
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotStore {
    static let appGroupID = "group.kr.co.cdd.PayBoardiOS"
    static let dataKey = "widget.snapshot.subscriptions.v1"

    static func save(subscriptions: [Subscription]) {
        let rows = subscriptions.map { subscription in
            let presetIcon = PresetIconCatalog.icon(for: subscription.iconKey)
            return WidgetSubscriptionSnapshot(
                id: subscription.id.uuidString,
                name: subscription.name,
                nextBillingDate: subscription.nextBillingDate,
                amount: NSDecimalNumber(decimal: subscription.amount).doubleValue,
                currencyCode: subscription.currencyCode,
                isAmountUndecided: subscription.isAmountUndecided,
                iconAssetName: presetIcon?.assetName,
                iconSystemSymbol: presetIcon?.systemSymbol,
                iconColorKey: subscription.iconColorKey,
                iconPNGData: widgetIconPNGData(for: presetIcon?.assetName)
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(rows),
              let defaults = UserDefaults(suiteName: appGroupID) else {
            return
        }

        defaults.set(data, forKey: dataKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func widgetIconPNGData(for assetName: String?) -> Data? {
        guard let assetName, !assetName.isEmpty else { return nil }
        #if canImport(UIKit)
        guard let image = UIImage(named: assetName) else { return nil }
        let targetSize = CGSize(width: 56, height: 56)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.pngData()
        #else
        return nil
        #endif
    }
}

struct WidgetSubscriptionSnapshot: Codable, Sendable {
    let id: String
    let name: String
    let nextBillingDate: Date
    let amount: Double
    let currencyCode: String
    let isAmountUndecided: Bool
    let iconAssetName: String?
    let iconSystemSymbol: String?
    let iconColorKey: String?
    let iconPNGData: Data?
}
