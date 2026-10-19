import SwiftUI
import Domain
import Data
import DesignSystem
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

public struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let original: Subscription?
    private let onSave: (Subscription) async -> Void

    @State private var name: String
    @State private var category: SubscriptionCategory
    @State private var amountText: String
    @State private var isAmountUndecided: Bool
    @State private var nextBillingDate: Date
    @State private var billingCycle: BillingCycle
    @State private var billingDay: Int
    @State private var customCategoryName: String
    @State private var notificationsEnabled: Bool
    @State private var isAutoPayEnabled: Bool
    @State private var isPinned: Bool
    @State private var selectedIconKey: String
    @State private var selectedIconColorKey: String
    @State private var memo: String
    @State private var query = ""
    @State private var isPresentingIconSearch = false
    @State private var isSaving = false
    @State private var validationMessageKey: String?
    @State private var overduePayload: Subscription?
    @State private var isPresentingAIInput = false
    @State private var aiInputText = ""
    @State private var isParsingAIInput = false
    @State private var aiInputFailed = false
    @State private var aiPhotoItem: PhotosPickerItem?
    @State private var aiDrafts: [Subscription] = []
    @State private var aiSelectedIDs: Set<UUID> = []
    @FocusState private var focusedField: FocusedField?

    private let allIcons = PresetIconCatalog.all()

    private enum FocusedField {
        case amount
    }

    public init(original: Subscription?, onSave: @escaping (Subscription) async -> Void) {
        self.original = original
        self.onSave = onSave

        _name = State(initialValue: original?.name ?? "")
        _category = State(initialValue: original?.category ?? .other)
        _amountText = State(initialValue: original?.isAmountUndecided == true ? "" : Self.formattedAmountInput(from: original?.amount))
        _isAmountUndecided = State(initialValue: original?.isAmountUndecided ?? false)
        _nextBillingDate = State(initialValue: original?.nextBillingDate ?? .now)
        _billingCycle = State(initialValue: original?.billingCycle ?? .monthly)
        _billingDay = State(initialValue: BillingDateCalculator.resolvedAnchorDay(
            for: original?.nextBillingDate ?? .now,
            anchorDay: original?.billingAnchorDay
        ))
        _customCategoryName = State(initialValue: original?.customCategoryName ?? "")
        _notificationsEnabled = State(initialValue: original?.notificationsEnabled ?? true)
        _isAutoPayEnabled = State(initialValue: original?.isAutoPayEnabled ?? false)
        _isPinned = State(initialValue: original?.isPinned ?? false)
        _selectedIconKey = State(initialValue: original?.iconKey ?? "preset_1")
        _selectedIconColorKey = State(initialValue: original?.iconColorKey ?? "blue")
        _memo = State(initialValue: original?.memo ?? "")
    }

    private var filteredIcons: [PresetIcon] {
        guard !query.isEmpty else { return Array(allIcons.prefix(50)) }
        return Array(PresetIconCatalog.search(query).prefix(50))
    }

    public var body: some View {
        NavigationStack {
            Form {
                if isAIInputAvailable {
                    Section {
                        Button {
                            isPresentingAIInput = true
                        } label: {
                            Label("service_editor.ai.button", systemImage: "apple.intelligence")
                        }
                    }
                }

                Section("service_editor.section.basic") {
                    nameField
                    Picker("service_editor.category", selection: $category) {
                        ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                            Text(LocalizedStringKey(category.labelKey)).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    if category == .other {
                        TextField("service_editor.category.custom", text: $customCategoryName)
                    }
                    amountField
                    Toggle("service_editor.autoPayEnabled", isOn: $isAutoPayEnabled)
                    Toggle("service_editor.pinned", isOn: $isPinned)
                    Picker("service_editor.billingCycle", selection: $billingCycle) {
                        Text("service_editor.billing.monthly").tag(BillingCycle.monthly)
                        Text("service_editor.billing.yearly").tag(BillingCycle.yearly)
                        Text("service_editor.billing.custom30").tag(BillingCycle.customDays(30))
                    }
                    .pickerStyle(.menu)
                    .onChange(of: billingCycle) { _, cycle in
                        if cycle == .monthly {
                            billingDay = Calendar.current.component(.day, from: nextBillingDate)
                        }
                    }
                    if billingCycle == .monthly {
                        Picker("service_editor.billingDay", selection: $billingDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("service_editor.billingDay.value \(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: billingDay) { _, day in
                            nextBillingDate = Self.date(inMonthOf: nextBillingDate, day: day)
                        }
                    } else {
                        DatePicker("service_editor.nextBillingDate", selection: $nextBillingDate, displayedComponents: .date)
                    }
                    Toggle("service_editor.notificationsEnabled", isOn: $notificationsEnabled)
                }

                Section("service_editor.section.icon") {
                    Button {
                        isPresentingIconSearch = true
                    } label: {
                        HStack(spacing: PayBoardSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.payMuted)
                            if query.isEmpty {
                                Text("service_editor.icon.search")
                                    .foregroundStyle(Color.payMuted)
                            } else {
                                Text(query)
                                    .foregroundStyle(Color.primary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, PayBoardSpacing.xs)
                    }
                    .buttonStyle(.plain)

                    ScrollView(.horizontal) {
                        HStack(spacing: PayBoardSpacing.sm) {
                            ForEach(filteredIcons) { icon in
                                Button {
                                    selectedIconKey = icon.key
                                } label: {
                                    iconGlyph(for: icon, size: 28)
                                    .padding(PayBoardSpacing.sm)
                                    .background(selectedIconKey == icon.key ? selectedIconColor.opacity(0.18) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, PayBoardSpacing.xs)
                    }

                    if !isUsingAssetIcon {
                        Text("service_editor.icon.color")
                            .font(.caption)
                            .foregroundStyle(Color.payMuted)

                        ScrollView(.horizontal) {
                            HStack(spacing: PayBoardSpacing.sm) {
                                ForEach(PayBoardIconColor.allCases) { iconColor in
                                    Button {
                                        selectedIconColorKey = iconColor.rawValue
                                    } label: {
                                        Circle()
                                            .fill(iconColor.color)
                                            .frame(width: 24, height: 24)
                                            .overlay {
                                                if selectedIconColorKey == iconColor.rawValue {
                                                    Circle()
                                                        .stroke(Color.primary.opacity(0.4), lineWidth: 2)
                                                        .padding(-3)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, PayBoardSpacing.xs)
                        }
                    }
                }

                Section("service_editor.section.memo") {
                    TextField("service_editor.memo", text: $memo, axis: .vertical)
                }
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.immediately)
            #endif
            .navigationTitle(Text(original == nil ? "service_editor.title.new" : "service_editor.title.edit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving)
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.confirm") {
                        focusedField = nil
                    }
                }
                #endif
            }
            .sheet(isPresented: $isPresentingIconSearch) {
                iconSearchSheet
            }
            .alert(
                "service_editor.overdue.title",
                isPresented: Binding(get: { overduePayload != nil }, set: { if !$0 { overduePayload = nil } }),
                presenting: overduePayload
            ) { payload in
                Button("service_editor.overdue.complete") {
                    Task {
                        await commit(Self.paidUntilYesterday(payload))
                    }
                }
                Button("service_editor.overdue.keep") {
                    Task {
                        await commit(payload)
                    }
                }
                Button("common.cancel", role: .cancel) {}
            } message: { _ in
                Text("service_editor.overdue.message")
            }
            .sheet(isPresented: $isPresentingAIInput) {
                aiInputSheet
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func save() async {
        guard !isSaving else { return }
        dismissAmountFocus()
        let amount: Decimal
        if isAmountUndecided {
            amount = .zero
        } else {
            let sanitizedAmountText = Self.sanitizedAmountText(amountText)
            guard let parsedAmount = Decimal(string: sanitizedAmountText), parsedAmount > 0 else {
                validationMessageKey = "service_editor.validation.amount"
                return
            }
            amount = parsedAmount
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessageKey = "service_editor.validation.name"
            return
        }

        let createdAt = original?.createdAt ?? .now
        let id = original?.id ?? UUID()

        let payload = Subscription(
            id: id,
            name: name,
            category: category,
            amount: amount,
            isAmountUndecided: isAmountUndecided,
            currencyCode: "KRW",
            billingCycle: billingCycle,
            nextBillingDate: nextBillingDate,
            billingAnchorDay: billingCycle == .monthly ? billingDay : (original?.nextBillingDate == nextBillingDate ? original?.billingAnchorDay : nil),
            lastPaymentDate: original?.lastPaymentDate,
            paymentHistoryDates: original?.paymentHistoryDates ?? [],
            iconKey: selectedIconKey,
            iconColorKey: selectedIconColorKey,
            customCategoryName: category == .other ? sanitizedCustomCategoryName : nil,
            notificationsEnabled: notificationsEnabled,
            isAutoPayEnabled: isAutoPayEnabled,
            isPinned: isPinned,
            isActive: true,
            memo: memo.isEmpty ? nil : memo,
            createdAt: createdAt,
            updatedAt: .now
        )

        let calendar = Calendar.current
        if original == nil, calendar.startOfDay(for: nextBillingDate) < calendar.startOfDay(for: .now) {
            overduePayload = payload
            return
        }
        await commit(payload)
    }

    private func commit(_ payload: Subscription) async {
        isSaving = true
        defer { isSaving = false }
        await onSave(payload)
        dismiss()
    }

    // 오늘 결제분은 아직 지난 게 아니므로 어제까지만 완료 처리한다.
    private static func paidUntilYesterday(_ payload: Subscription) -> Subscription {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        var paid = payload.completedThrough(yesterday)
        paid.updatedAt = .now
        return paid
    }

    private var sanitizedCustomCategoryName: String? {
        let trimmed = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var selectedIconColor: Color {
        Color.payIconTint(for: selectedIconColorKey)
    }

    private var isUsingAssetIcon: Bool {
        PresetIconCatalog.icon(for: selectedIconKey)?.assetName != nil
    }

    @ViewBuilder
    private func iconGlyph(for icon: PresetIcon, size: CGFloat) -> some View {
        if let assetName = icon.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: icon.systemSymbol)
                .font(.title3)
                .frame(width: size, height: size)
                .foregroundStyle(selectedIconColor)
        }
    }

    private var iconSearchSheet: some View {
        NavigationStack {
            List(filteredIcons) { icon in
                Button {
                    selectedIconKey = icon.key
                    query = PresetIconCatalog.localizedDisplayName(for: icon)
                    isPresentingIconSearch = false
                } label: {
                    HStack(spacing: PayBoardSpacing.md) {
                        iconGlyph(for: icon, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PresetIconCatalog.localizedDisplayName(for: icon))
                                .foregroundStyle(Color.primary)
                            Text(icon.key)
                                .font(.caption)
                                .foregroundStyle(Color.payMuted)
                        }
                        Spacer()
                        if selectedIconKey == icon.key {
                            Image(systemName: "checkmark")
                                .foregroundStyle(selectedIconColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("service_editor.icon.search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        isPresentingIconSearch = false
                    }
                }
            }
            .searchable(text: $query, prompt: Text("service_editor.icon.search"))
        }
    }

    private var isAIInputAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return original == nil && SubscriptionDraftParser.isAvailable
        }
        #endif
        return false
    }

    private var aiInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("service_editor.ai.placeholder", text: $aiInputText, axis: .vertical)
                        .lineLimit(3...6)
                    PhotosPicker(selection: $aiPhotoItem, matching: .screenshots) {
                        Label("service_editor.ai.photo", systemImage: "photo")
                    }
                    .disabled(isParsingAIInput)
                } footer: {
                    if aiInputFailed {
                        Text("service_editor.ai.error")
                            .foregroundStyle(Color.payDanger)
                    } else {
                        Text("service_editor.ai.footer")
                    }
                }

                if !aiDrafts.isEmpty {
                    Section("service_editor.ai.results") {
                        ForEach(aiDrafts) { draft in
                            Toggle(isOn: aiSelectionBinding(for: draft.id)) {
                                aiDraftRow(draft)
                            }
                        }
                    }
                }
            }
            .onChange(of: aiPhotoItem) { _, item in
                guard let item else { return }
                aiPhotoItem = nil
                Task {
                    await fillFromAIPhoto(item)
                }
            }
            .navigationTitle("service_editor.ai.button")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        isPresentingAIInput = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isParsingAIInput || isSaving {
                        ProgressView()
                    } else if !aiDrafts.isEmpty {
                        Button("service_editor.ai.addSelected \(aiSelectedIDs.count)") {
                            Task {
                                await saveAIDrafts()
                            }
                        }
                        .disabled(aiSelectedIDs.isEmpty)
                    } else {
                        Button("service_editor.ai.fill") {
                            Task {
                                await fillFromAIInput()
                            }
                        }
                        .disabled(aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func fillFromAIInput() async {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *), !isParsingAIInput else { return }
        isParsingAIInput = true
        aiInputFailed = false
        aiDrafts = []
        defer { isParsingAIInput = false }
        do {
            let parsed = try await SubscriptionDraftParser.parse(aiInputText)
            let drafts = parsed.map { $0.subscription() }
            if let only = parsed.first, parsed.count == 1 {
                apply(drafts[0])
                // 금액을 말하지 않았을 뿐이면 변동으로 두지 않고 사용자가 입력하게 한다.
                isAmountUndecided = only.isAmountVariable
                // 바로 저장하는 일괄 추가와 달리 사용자가 저장하므로 지난 결제일을 그대로 두고 저장 시 확인한다.
                if let date = only.currentPeriodBillingDate() {
                    nextBillingDate = date
                }
                isPresentingAIInput = false
            } else if drafts.isEmpty {
                aiInputFailed = true
            } else {
                aiDrafts = drafts
                aiSelectedIDs = Set(drafts.map(\.id))
            }
        } catch {
            aiInputFailed = true
        }
        #endif
    }

    private func fillFromAIPhoto(_ item: PhotosPickerItem) async {
        #if canImport(FoundationModels)
        guard #available(iOS 26, macOS 26, *), !isParsingAIInput else { return }
        isParsingAIInput = true
        var text: String?
        if let data = try? await item.loadTransferable(type: Data.self) {
            text = try? await SubscriptionDraftParser.recognizeText(in: data)
        }
        isParsingAIInput = false
        guard let text, !text.isEmpty else {
            aiInputFailed = true
            return
        }
        // 인식 결과를 입력란에 남겨 실패 시 사용자가 고쳐서 다시 채울 수 있게 한다.
        aiInputText = text
        await fillFromAIInput()
        #endif
    }

    private func apply(_ draft: Subscription) {
        name = draft.name
        validationMessageKey = nil
        category = draft.category
        isAmountUndecided = draft.isAmountUndecided
        amountText = draft.isAmountUndecided ? "" : Self.formattedAmountInput(from: draft.amount)
        billingCycle = draft.billingCycle
        nextBillingDate = draft.nextBillingDate
        billingDay = BillingDateCalculator.resolvedAnchorDay(for: draft.nextBillingDate, anchorDay: draft.billingAnchorDay)
        isAutoPayEnabled = draft.isAutoPayEnabled
        memo = draft.memo ?? memo
        selectedIconKey = draft.iconKey
        if let icon = PresetIconCatalog.icon(for: draft.iconKey) {
            query = PresetIconCatalog.localizedDisplayName(for: icon)
        }
    }

    // ponytail: 항목마다 onSave(자동 백업 포함)를 따로 호출. 대량 입력이 잦아지면 일괄 저장 API 로 바꾼다.
    private func saveAIDrafts() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        for draft in aiDrafts where aiSelectedIDs.contains(draft.id) {
            await onSave(draft)
        }
        isPresentingAIInput = false
        dismiss()
    }

    private func aiSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { aiSelectedIDs.contains(id) },
            set: { isOn in
                if isOn {
                    aiSelectedIDs.insert(id)
                } else {
                    aiSelectedIDs.remove(id)
                }
            }
        )
    }

    private func aiDraftRow(_ draft: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(draft.name)
            HStack(spacing: 4) {
                if draft.isAmountUndecided {
                    Text("service_editor.amount.variable")
                } else {
                    Text(Self.formattedAmountInput(from: draft.amount))
                    Text("service_editor.amount.suffix")
                }
                Text("·")
                Text(draft.nextBillingDate, format: .dateTime.month().day())
            }
            .font(.caption)
            .foregroundStyle(Color.payMuted)
        }
    }

    @ViewBuilder
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("service_editor.name", text: nameInputBinding)

            if nameHasError {
                Text("service_editor.validation.name")
                    .font(.caption)
                    .foregroundStyle(Color.payDanger)
            }
        }
    }

    @ViewBuilder
    private var amountField: some View {
        Toggle("service_editor.amount.variable", isOn: $isAmountUndecided)
            .listRowSeparator(.hidden)
            .onChange(of: isAmountUndecided) { _, isUndecided in
                if isUndecided {
                    amountText = ""
                    validationMessageKey = nil
                    focusedField = nil
                }
            }

        if !isAmountUndecided {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: PayBoardSpacing.xs) {
                    #if os(iOS)
                    TextField("service_editor.amount", text: amountInputBinding)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .amount)
                        .submitLabel(.done)
                    #else
                    TextField("service_editor.amount", text: amountInputBinding)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .amount)
                        .submitLabel(.done)
                    #endif
                    Text("service_editor.amount.suffix")
                        .foregroundStyle(Color.payMuted)
                }

                if amountHasError {
                    Text("service_editor.validation.amount")
                        .font(.caption)
                        .foregroundStyle(Color.payDanger)
                }
            }
            .listRowSeparator(.hidden)
        }
    }

    private var nameHasError: Bool {
        validationMessageKey == "service_editor.validation.name"
    }

    private var amountHasError: Bool {
        validationMessageKey == "service_editor.validation.amount"
    }

    private var nameInputBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                name = newValue
                if nameHasError && !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    validationMessageKey = nil
                }
            }
        )
    }

    private var amountInputBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                let sanitized = Self.sanitizedAmountText(newValue)
                amountText = Self.groupedAmountText(sanitized)
                if amountHasError && !sanitized.isEmpty {
                    validationMessageKey = nil
                }
            }
        )
    }

    private func dismissAmountFocus() {
        guard focusedField == .amount else { return }
        focusedField = nil
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    // 월간 결제는 일자만 고르므로 현재 결제일이 속한 달 안에서 일자만 바꾼다. 지난 날짜면 저장 시 결제 완료 여부를 묻는다.
    private static func date(inMonthOf date: Date, day: Int, calendar: Calendar = .current) -> Date {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        return BillingDateCalculator.upcoming(day: day, cycle: .monthly, from: monthStart, calendar: calendar)
    }

    private static func formattedAmountInput(from amount: Decimal?) -> String {
        guard let amount else { return "" }
        let plain = NSDecimalNumber(decimal: amount).stringValue
        let integerPart = plain.split(separator: ".").first.map(String.init) ?? plain
        return groupedAmountText(sanitizedAmountText(integerPart))
    }

    private static func sanitizedAmountText(_ text: String) -> String {
        text.filter(\.isNumber)
    }

    private static func groupedAmountText(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let number = NSDecimalNumber(string: digits)
        guard number != .notANumber else { return digits }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? digits
    }
}

#Preview("New Subscription") {
    ServiceEditorView(original: nil) { _ in
        // Preview-only no-op save action.
    }
}

#Preview("Edit Subscription") {
    ServiceEditorView(
        original: SampleData.subscriptions.first
    ) { _ in
        // Preview-only no-op save action.
    }
}
