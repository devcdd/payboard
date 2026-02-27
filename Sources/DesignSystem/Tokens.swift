import SwiftUI

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

public extension Color {
    static let payBackground = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let payCard = Color.white
    static let payAccent = Color(red: 0.04, green: 0.47, blue: 0.83)
    static let payDanger = Color(red: 0.83, green: 0.16, blue: 0.16)
    static let payMuted = Color(red: 0.43, green: 0.46, blue: 0.52)
}
