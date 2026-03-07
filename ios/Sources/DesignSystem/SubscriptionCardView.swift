import SwiftUI
import Domain

public struct SubscriptionCardView: View {
    public let subscription: Subscription
    public let presetIcon: PresetIcon?
    public let showIcon: Bool
    public let showDateBelowLabel: Bool
    public let referenceMonth: Date
    public let billingDateOverride: Date?
    public let onTapIcon: (() -> Void)?

    public init(
        subscription: Subscription,
        presetIcon: PresetIcon?,
        showIcon: Bool = true,
        showDateBelowLabel: Bool = false,
        referenceMonth: Date = .now,
        billingDateOverride: Date? = nil,
        onTapIcon: (() -> Void)? = nil
    ) {
        self.subscription = subscription
        self.presetIcon = presetIcon
        self.showIcon = showIcon
        self.showDateBelowLabel = showDateBelowLabel
        self.referenceMonth = referenceMonth
        self.billingDateOverride = billingDateOverride
        self.onTapIcon = onTapIcon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PayBoardSpacing.sm) {
            HStack(spacing: PayBoardSpacing.sm) {
                if showIcon {
                    Button {
                        onTapIcon?()
                    } label: {
                        iconView
                            .frame(width: 28, height: 28)
                            .padding(PayBoardSpacing.xs)
                            .background(iconBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control))
                    }
                    .buttonStyle(.plain)
                    .disabled(onTapIcon == nil)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let customCategoryName = subscription.customCategoryName,
                       subscription.category == .other {
                        HStack(spacing: 4) {
                            Text(customCategoryName)
                                .font(.caption2)
                                .foregroundStyle(Color.payMuted)
                            if subscription.isAutoPayEnabled {
                                Text(verbatim: "·")
                                    .font(.caption2)
                                    .foregroundStyle(Color.payMuted)
                                Text("subscription.autoPay")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.green)
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(subscription.category.labelKey))
                                .font(.caption2)
                                .foregroundStyle(Color.payMuted)
                            if subscription.isAutoPayEnabled {
                                Text(verbatim: "·")
                                    .font(.caption2)
                                    .foregroundStyle(Color.payMuted)
                                Text("subscription.autoPay")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                }

                Spacer()
            }

            Text(formattedAmount)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if showDateBelowLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text("subscription.nextBilling")
                        .font(.caption2)
                        .foregroundStyle(Color.payMuted)
                    Text(formattedDate)
                        .font(.caption2.weight(.medium))
                }
            } else {
                HStack {
                    Text(isPaidForReferenceMonth ? "subscription.paymentStatus" : "subscription.nextBilling")
                        .font(.caption2)
                        .foregroundStyle(Color.payMuted)
                    Spacer()
                    Text(formattedDate)
                        .font(.caption2.weight(.medium))
                }
            }
        }
        .padding(PayBoardSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: PayBoardRadius.card)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private var formattedAmount: String {
        if subscription.isAmountUndecided {
            return NSLocalizedString("common.variable", comment: "")
        }
        if subscription.currencyCode.uppercased() == "KRW" {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let value = formatter.string(from: subscription.amount as NSDecimalNumber) ?? "\(subscription.amount)"
            return value + NSLocalizedString("currency.krw.suffix", comment: "")
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = subscription.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: subscription.amount as NSDecimalNumber) ?? "\(subscription.amount)"
    }

    private var iconTintColor: Color {
        Color.payIconTint(for: subscription.iconColorKey)
    }

    @ViewBuilder
    private var iconView: some View {
        if let assetName = presetIcon?.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: presetIcon?.systemSymbol ?? "app.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconTintColor)
        }
    }

    private var iconBackgroundColor: Color {
        if presetIcon?.assetName != nil {
            return Color.black.opacity(0.05)
        }
        return iconTintColor.opacity(0.14)
    }

    private var formattedDate: String {
        if isPaidForReferenceMonth {
            return NSLocalizedString("subscription.paymentDone", comment: "")
        }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: effectiveBillingDate)
    }

    private var cardBackgroundColor: Color {
        if isPaidForReferenceMonth {
            return Color.green.opacity(0.18)
        }
        if daysUntilBilling <= 1 {
            return Color.red.opacity(0.12)
        }
        if daysUntilBilling <= 3 {
            return Color.yellow.opacity(0.18)
        }
        return Color.payCard
    }

    private var daysUntilBilling: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let billingDay = calendar.startOfDay(for: effectiveBillingDate)
        return calendar.dateComponents([.day], from: today, to: billingDay).day ?? Int.max
    }

    private var effectiveBillingDate: Date {
        billingDateOverride ?? subscription.nextBillingDate
    }

    private var isPaidForCurrentCycle: Bool {
        if isPaidForReferenceMonth {
            return true
        }
        guard let lastPaymentDate = subscription.lastPaymentDate else { return false }
        let calendar = Calendar.current
        let previousDate: Date
        switch subscription.billingCycle {
        case .monthly:
            previousDate = calendar.date(byAdding: .month, value: -1, to: subscription.nextBillingDate) ?? subscription.nextBillingDate
        case .yearly:
            previousDate = calendar.date(byAdding: .year, value: -1, to: subscription.nextBillingDate) ?? subscription.nextBillingDate
        case let .customDays(days):
            previousDate = calendar.date(byAdding: .day, value: -max(1, days), to: subscription.nextBillingDate) ?? subscription.nextBillingDate
        }
        return lastPaymentDate >= previousDate && lastPaymentDate < subscription.nextBillingDate
    }

    private var isPaidForReferenceMonth: Bool {
        guard let lastPaymentDate = subscription.lastPaymentDate else { return false }
        return Calendar.current.isDate(lastPaymentDate, equalTo: referenceMonth, toGranularity: .month)
    }
}
