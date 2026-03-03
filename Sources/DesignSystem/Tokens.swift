import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum PayBoardSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum PayBoardRadius {
    public static let card: CGFloat = 16
    public static let control: CGFloat = 10
}

public enum PayBoardIconColor: String, CaseIterable, Identifiable {
    case blue
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case indigo
    case purple
    case pink
    case brown
    case gray

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        }
    }
}

public extension Color {
    static var payBackground: Color {
        adaptiveColor(
            light: Color(red: 0.96, green: 0.97, blue: 0.99),
            dark: Color(red: 0.08, green: 0.09, blue: 0.11)
        )
    }

    static var payCard: Color {
        adaptiveColor(
            light: Color.white,
            dark: Color(red: 0.12, green: 0.13, blue: 0.16)
        )
    }

    static let payAccent = Color(red: 0.04, green: 0.47, blue: 0.83)
    static let payDanger = Color(red: 0.83, green: 0.16, blue: 0.16)

    static func payIconTint(for key: String) -> Color {
        PayBoardIconColor(rawValue: key)?.color ?? .payAccent
    }

    static var payMuted: Color {
        adaptiveColor(
            light: Color(red: 0.43, green: 0.46, blue: 0.52),
            dark: Color(red: 0.67, green: 0.70, blue: 0.76)
        )
    }

    private static func adaptiveColor(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        let lightUIColor = UIColor(light)
        let darkUIColor = UIColor(dark)
        return Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? darkUIColor : lightUIColor
            }
        )
        #elseif canImport(AppKit)
        let lightNSColor = NSColor(light)
        let darkNSColor = NSColor(dark)
        return Color(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkNSColor : lightNSColor
                }
            )
        )
        #else
        return light
        #endif
    }
}
