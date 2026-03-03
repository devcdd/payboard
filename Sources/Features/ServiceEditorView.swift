import SwiftUI
import Domain
import Data
import DesignSystem
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
    @State private var customCategoryName: String
    @State private var notificationsEnabled: Bool
    @State private var selectedIconKey: String
    @State private var selectedIconColorKey: String
    @State private var memo: String
    @State private var query = ""
    @State private var isPresentingIconSearch = false
    @State private var isSaving = false
    @State private var validationMessageKey: String?
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
        _customCategoryName = State(initialValue: original?.customCategoryName ?? "")
        _notificationsEnabled = State(initialValue: original?.notificationsEnabled ?? true)
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
                Section("service_editor.section.basic") {
                    TextField("service_editor.name", text: $name)
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
                    DatePicker("service_editor.nextBillingDate", selection: $nextBillingDate, displayedComponents: .date)
                    Picker("service_editor.billingCycle", selection: $billingCycle) {
                        Text("service_editor.billing.monthly").tag(BillingCycle.monthly)
                        Text("service_editor.billing.yearly").tag(BillingCycle.yearly)
                        Text("service_editor.billing.custom30").tag(BillingCycle.customDays(30))
                    }
                    .pickerStyle(.menu)
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

                if let messageKey = validationMessageKey,
                   messageKey != "service_editor.validation.amount" {
                    Section {
                        Text(LocalizedStringKey(messageKey))
                            .foregroundStyle(Color.payDanger)
                    }
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
            lastPaymentDate: original?.lastPaymentDate,
            iconKey: selectedIconKey,
            iconColorKey: selectedIconColorKey,
            customCategoryName: category == .other ? sanitizedCustomCategoryName : nil,
            notificationsEnabled: notificationsEnabled,
            isActive: true,
            memo: memo.isEmpty ? nil : memo,
            createdAt: createdAt,
            updatedAt: .now
        )

        isSaving = true
        defer { isSaving = false }
        await onSave(payload)
        dismiss()
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
            .listRowSeparator(.hidden)
        }

        if validationMessageKey == "service_editor.validation.amount" {
            Text("service_editor.validation.amount")
                .font(.caption)
                .foregroundStyle(Color.payDanger)
                .listRowSeparator(.hidden)
        }
    }

    private var amountInputBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                let sanitized = Self.sanitizedAmountText(newValue)
                amountText = Self.groupedAmountText(sanitized)
                if validationMessageKey == "service_editor.validation.amount" {
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
