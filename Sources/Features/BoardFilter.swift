import Foundation

public enum BoardFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case thisWeek = "이번주"
    case thisMonth = "이번달"

    public var id: Self { self }
}
