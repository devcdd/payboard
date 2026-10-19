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

    /// 같은 날짜에 여러 마커가 겹치면 우선순위가 높은 쪽을 남긴다
    public func merged(with other: PaymentCalendarMarker?) -> PaymentCalendarMarker {
        guard let other else { return self }
        return other.priority >= priority ? other : self
    }
}
