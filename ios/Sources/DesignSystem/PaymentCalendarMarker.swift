import Foundation
import SwiftUI

/// 앱 캘린더와 위젯 캘린더가 같은 규칙과 색으로 날짜 점을 표시하도록 공유하는 마커
public enum PaymentCalendarMarker: Sendable {
    case scheduled
    case warning
    case critical
    case paid

    public var dotColor: Color {
        switch self {
        case .scheduled:
            return Color.payAccent.opacity(0.85)
        case .warning:
            return Color.yellow.opacity(0.95)
        case .critical:
            return Color.red.opacity(0.95)
        case .paid:
            return Color.green.opacity(0.95)
        }
    }

    public var priority: Int {
        switch self {
        case .scheduled:
            return 0
        case .warning:
            return 1
        case .critical:
            return 2
        case .paid:
            return 3
        }
    }

    /// 결제일까지 하루 이내면 critical, 사흘 이내면 warning, 그 외에는 scheduled
    public static func upcoming(billingDate: Date, today: Date, calendar: Calendar = .current) -> PaymentCalendarMarker {
        let start = calendar.startOfDay(for: today)
        let billingDay = calendar.startOfDay(for: billingDate)
        let days = calendar.dateComponents([.day], from: start, to: billingDay).day ?? Int.max
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .scheduled
    }
}

/// 캘린더 날짜 아래에 아이콘으로 표시할 결제 한 건
public struct PaymentCalendarIconItem: Identifiable, Hashable, Sendable {
    public let subscriptionID: String
    public let marker: PaymentCalendarMarker

    public var id: String { "\(subscriptionID)-\(isPaid)" }
    public var isPaid: Bool { marker == .paid }

    public init(subscriptionID: String, marker: PaymentCalendarMarker) {
        self.subscriptionID = subscriptionID
        self.marker = marker
    }

    /// 아직 결제 전인 항목 중 가장 임박한 상태에 따라 날짜 숫자 색을 정한다
    public static func dayTextColor(for items: [PaymentCalendarIconItem]) -> Color? {
        let urgent = items.filter { !$0.isPaid }.map(\.marker).max { $0.priority < $1.priority }
        switch urgent {
        case .critical:
            return .red
        case .warning:
            return .orange
        default:
            return nil
        }
    }

    /// 결제 전 항목을 먼저, 같은 상태끼리는 임박한 순서로 정렬하고 중복을 없앤다
    public static func sorted(_ items: [PaymentCalendarIconItem]) -> [PaymentCalendarIconItem] {
        var seen = Set<String>()
        return items
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.isPaid != rhs.isPaid { return !lhs.isPaid }
                return lhs.marker.priority > rhs.marker.priority
            }
    }
}

/// 날짜 아래 아이콘 줄. 넘치는 항목은 "+n"으로 줄이고, 결제 완료 항목은 흐리게 보여준다
public struct PaymentCalendarIconRow<Icon: View>: View {
    private let items: [PaymentCalendarIconItem]
    private let maxIcons: Int
    private let iconSize: CGFloat
    private let icon: (PaymentCalendarIconItem) -> Icon

    public init(
        items: [PaymentCalendarIconItem],
        maxIcons: Int,
        iconSize: CGFloat,
        @ViewBuilder icon: @escaping (PaymentCalendarIconItem) -> Icon
    ) {
        self.items = items
        self.maxIcons = maxIcons
        self.iconSize = iconSize
        self.icon = icon
    }

    private var visibleItems: [PaymentCalendarIconItem] {
        let count = items.count <= maxIcons ? items.count : max(1, maxIcons - 1)
        return Array(items.prefix(count))
    }

    public var body: some View {
        let overflow = items.count - visibleItems.count
        HStack(spacing: 1) {
            ForEach(visibleItems) { item in
                icon(item)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.25))
                    .opacity(item.isPaid ? 0.4 : 1)
            }
            if overflow > 0 {
                Text(verbatim: "+\(overflow)")
                    .font(.system(size: iconSize * 0.75, weight: .semibold))
                    .foregroundStyle(Color.payMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(height: iconSize)
    }
}
