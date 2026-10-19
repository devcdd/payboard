#if canImport(FoundationModels)
import Foundation
import FoundationModels
import Vision
import Domain

@available(iOS 26, macOS 26, *)
@Generable
struct SubscriptionDraft {
    @Guide(description: "서비스 또는 결제 항목 이름. 예: 넷플릭스, 월세, 헬스장")
    var name: String
    var category: Category
    @Guide(description: "결제 금액(원 단위 정수). 언급이 없으면 nil")
    var amount: Int?
    var cycle: Cycle
    @Guide(description: "결제되는 날짜의 일(1~31). 언급이 없으면 nil")
    var billingDay: Int?
    @Guide(description: "연간 결제일 때 결제 월(1~12). 그 외에는 nil")
    var billingMonth: Int?
    @Guide(description: "자동이체·자동결제라고 언급했으면 true")
    var isAutoPay: Bool
    @Guide(description: "위 항목에 담기지 않는 추가 정보. 없으면 nil")
    var memo: String?

    // rawValue 를 SubscriptionCategory 와 맞춰 그대로 변환한다.
    @Generable
    enum Category: String {
        case video, music, productivity, cloud, housing, shopping, gaming, finance, education, health, other
    }

    @Generable
    enum Cycle {
        case monthly, yearly
    }
}

@available(iOS 26, macOS 26, *)
enum SubscriptionDraftParser {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func parse(_ text: String) async throws -> SubscriptionDraft {
        let session = LanguageModelSession(instructions: """
            사용자가 말로 설명한 정기결제(구독, 고정지출) 정보를 양식 필드로 추출한다.
            설명에 없는 값은 추측하지 말고 nil 로 둔다.
            결제 화면 캡처에서 인식한 글자일 수 있으니, 정기결제와 무관한 문구는 무시한다.
            """)
        return try await session.respond(to: text, generating: SubscriptionDraft.self).content
    }

    static func recognizeText(in imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "ko-KR"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: imageData)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
#endif
