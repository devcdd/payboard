import XCTest
@testable import Data
@testable import Domain

final class PresetIconSuggestionTests: XCTestCase {
    func testSuggestedIcon() {
        XCTAssertEqual(PresetIconCatalog.suggestedIcon(forName: "넷플릭스", category: .video)?.key, "icon_netflix")
        XCTAssertEqual(PresetIconCatalog.suggestedIcon(forName: "넷플릭스 프리미엄", category: .video)?.key, "icon_netflix")
        XCTAssertEqual(PresetIconCatalog.suggestedIcon(forName: "클로드 프로", category: .productivity)?.key, "icon_claude")
        XCTAssertEqual(PresetIconCatalog.suggestedIcon(forName: "월세", category: .housing)?.systemSymbol, "house")
        XCTAssertEqual(PresetIconCatalog.suggestedIcon(forName: "헬스장", category: .health)?.systemSymbol, "heart.text.square")
        XCTAssertNil(PresetIconCatalog.suggestedIcon(forName: "동네 모임 회비", category: .other))
    }
}
