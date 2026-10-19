#if canImport(FoundationModels)
import Foundation
import FoundationModels
import Vision
import Domain
import Data

@available(iOS 26, macOS 26, *)
@Generable
struct SubscriptionDraft {
    @Guide(description: "서비스 또는 결제 항목 이름. 예: 넷플릭스, 월세, 헬스장")
    var name: String
    var category: Category
    // 금액보다 먼저 생성되도록 앞에 둔다.
    @Guide(description: "변동금액, 금액 변동, 매달 다름, 사용량에 따라 다름처럼 금액이 고정되지 않았다고 했으면 true")
    var isAmountVariable: Bool
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
@Generable
struct SubscriptionDraftList {
    @Guide(description: "언급된 정기결제 항목들. 서비스마다 하나씩")
    var items: [SubscriptionDraft]
}

@available(iOS 26, macOS 26, *)
extension SubscriptionDraft {
    func subscription(now: Date = .now) -> Subscription {
        let category = SubscriptionCategory(rawValue: category.rawValue) ?? .other
        let cycle: BillingCycle = cycle == .yearly ? .yearly : .monthly
        let amount = amount.flatMap { $0 > 0 ? Decimal($0) : nil }
        return Subscription(
            name: name,
            category: category,
            amount: amount ?? .zero,
            isAmountUndecided: isAmountVariable || amount == nil,
            billingCycle: cycle,
            nextBillingDate: billingDay.map { BillingDateCalculator.upcoming(day: $0, month: billingMonth, cycle: cycle, from: now) } ?? now,
            billingAnchorDay: billingDay,
            iconKey: PresetIconCatalog.suggestedIcon(forName: name, category: category)?.key ?? "preset_1",
            isAutoPayEnabled: isAutoPay,
            memo: memo?.isEmpty == false ? memo : nil
        )
    }
}

@available(iOS 26, macOS 26, *)
enum SubscriptionDraftParser {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func parse(_ text: String) async throws -> [SubscriptionDraft] {
        let session = LanguageModelSession(instructions: """
            사용자가 말로 설명한 정기결제(구독, 고정지출) 정보를 양식 필드로 추출한다.
            설명에 없는 값은 추측하지 말고 nil 로 둔다.
            결제 화면 캡처에서 인식한 글자일 수 있으니, 정기결제와 무관한 문구는 무시한다.
            여러 서비스가 언급되면 각각 별도 항목으로 담는다.
            """)
        return try await session.respond(to: text, generating: SubscriptionDraftList.self).content.items
    }

    static func recognizeText(in imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "ko-KR"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: imageData)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
#endif
