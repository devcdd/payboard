import Foundation

public enum BoardFilter: String, CaseIterable, Identifiable {
    case all
    case thisWeek
    case thisMonth

    public var id: Self { self }

    public var titleKey: String {
        switch self {
        case .all:
            return "board.filter.all"
        case .thisWeek:
            return "board.filter.thisWeek"
        case .thisMonth:
            return "board.filter.thisMonth"
        }
    }
}
