import SwiftUI
import Domain
import Data
import DesignSystem

public struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Subscription?
    private let onSave: (Subscription) async -> Void

    @State private var name: String
    @State private var category: SubscriptionCategory
    @State private var amountText: String
    @State private var nextBillingDate: Date
    @State private var billingCycle: BillingCycle
    @State private var selectedIconKey: String
    @State private var memo: String
    @State private var query = ""
    @State private var validationMessage: String?

    private let allIcons = PresetIconCatalog.all()

    public init(original: Subscription?, onSave: @escaping (Subscription) async -> Void) {
        self.original = original
        self.onSave = onSave

        _name = State(initialValue: original?.name ?? "")
        _category = State(initialValue: original?.category ?? .other)
        _amountText = State(initialValue: original.map { "\($0.amount)" } ?? "")
        _nextBillingDate = State(initialValue: original?.nextBillingDate ?? .now)
        _billingCycle = State(initialValue: original?.billingCycle ?? .monthly)
        _selectedIconKey = State(initialValue: original?.iconKey ?? "preset_1")
        _memo = State(initialValue: original?.memo ?? "")
    }

    private var filteredIcons: [PresetIcon] {
        guard !query.isEmpty else { return Array(allIcons.prefix(50)) }
        return Array(PresetIconCatalog.search(query).prefix(50))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("서비스 이름", text: $name)
                    Picker("카테고리", selection: $category) {
                        ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    amountField
                    DatePicker("다음 결제일", selection: $nextBillingDate, displayedComponents: .date)
                    Picker("결제 주기", selection: $billingCycle) {
                        Text("Monthly").tag(BillingCycle.monthly)
                        Text("Yearly").tag(BillingCycle.yearly)
                        Text("30 Days").tag(BillingCycle.customDays(30))
                    }
                }

                Section("아이콘") {
                    TextField("아이콘 검색", text: $query)
                    ScrollView(.horizontal) {
                        HStack(spacing: PayBoardSpacing.sm) {
                            ForEach(filteredIcons) { icon in
                                Button {
                                    selectedIconKey = icon.key
                                } label: {
                                    VStack {
                                        Image(systemName: icon.systemSymbol)
                                        Text(icon.displayName)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .padding(PayBoardSpacing.sm)
                                    .background(selectedIconKey == icon.key ? Color.payAccent.opacity(0.18) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, PayBoardSpacing.xs)
                    }
                }

                Section("메모") {
                    TextField("옵션 메모", text: $memo, axis: .vertical)
                }

                if let message = validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(Color.payDanger)
                    }
                }
            }
            .navigationTitle(original == nil ? "구독 추가" : "구독 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            await save()
                        }
                    }
                }
            }
        }
    }

    private func save() async {
        guard let amount = Decimal(string: amountText), amount > 0 else {
            validationMessage = "금액은 0보다 커야 합니다."
            return
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "서비스 이름을 입력하세요."
            return
        }

        let createdAt = original?.createdAt ?? .now
        let id = original?.id ?? UUID()

        let payload = Subscription(
            id: id,
            name: name,
            category: category,
            amount: amount,
            currencyCode: "KRW",
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate,
            iconKey: selectedIconKey,
            isActive: true,
            memo: memo.isEmpty ? nil : memo,
            createdAt: createdAt,
            updatedAt: .now
        )

        await onSave(payload)
        dismiss()
    }

    @ViewBuilder
    private var amountField: some View {
        #if os(iOS)
        TextField("금액", text: $amountText)
            .keyboardType(.decimalPad)
        #else
        TextField("금액", text: $amountText)
        #endif
    }
}
