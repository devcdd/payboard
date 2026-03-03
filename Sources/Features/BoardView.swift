import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Domain
import Data
import DesignSystem

public enum BoardDisplayMode: String, CaseIterable, Sendable {
    case board
    case calendar
}

public struct BoardView: View {
    @ObservedObject var viewModel: BoardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    private let displayMode: BoardDisplayMode
    @AppStorage("board.columnsCount") private var columnsCount = 2
    @AppStorage("board.selectedSort") private var selectedSortStorage = BoardSortOption.nextBillingAsc.rawValue
    @AppStorage("board.selectedFilter") private var selectedFilterStorage = BoardFilter.all.rawValue
    @State private var selectedCalendarDate: Date = .now
    @State private var displayedMonth: Date = .now
    @State private var isPresentingMonthSelector = false
    @State private var isDashboardExpanded = false
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth = Calendar.current.component(.month, from: .now)
    @State private var boardSearchQuery = ""
    @State private var selectedSort: BoardSortOption = .nextBillingAsc
    @State private var hasRestoredPersistedViewState = false
    @State private var isSelectionMode = false
    @State private var selectedSubscriptionIDs: Set<UUID> = []
    @State private var isPresentingBulkDateSheet = false
    @State private var bulkNextBillingDate = Date()
    @State private var quickIconTarget: Subscription?
    @State private var quickIconQuery = ""
    @State private var suppressCardTapSubscriptionID: UUID?
    @State private var pendingDeleteSubscription: Subscription?
    @State private var pendingBulkDeleteIDs: Set<UUID> = []
    @State private var isPresentingBulkDeleteConfirmation = false
    @AppStorage("board.customSortOrder") private var customSortOrderStorage = ""
    @State private var customSortOrderIDs: [UUID] = []
    @State private var hasLoadedCustomSortOrder = false
    @State private var isCustomSortEditing = false
    @State private var draggedCustomSortID: UUID?
    @State private var editorSheet: EditorSheet?
    @FocusState private var isBoardSearchFocused: Bool

    public init(
        viewModel: BoardViewModel,
        settingsViewModel: SettingsViewModel,
        displayMode: BoardDisplayMode = .board
    ) {
        self.viewModel = viewModel
        self.settingsViewModel = settingsViewModel
        self.displayMode = displayMode
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: PayBoardSpacing.md),
            count: sanitizedColumnsCount
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.payBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerRow

                    ScrollView {
                        VStack(alignment: .leading, spacing: PayBoardSpacing.lg) {
                            dashboardSection
                            if displayMode == .calendar {
                                calendarSection
                            } else {
                                subscriptionsSection
                            }
                        }
                        .padding(PayBoardSpacing.lg)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            if isBoardSearchFocused {
                                isBoardSearchFocused = false
                            }
                        }
                    )
                }

                if shouldShowFloatingAddButton {
                    floatingAddButton
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task {
                restorePersistedViewStateIfNeeded()
                await viewModel.onAppear()
                await viewModel.syncReminderOptions(
                    settingsViewModel.effectiveReminderOptions,
                    hour: settingsViewModel.reminderHour,
                    minute: settingsViewModel.reminderMinute
                )
                loadCustomSortOrderIfNeeded()
                syncCustomSortOrder(with: viewModel.subscriptions)
            }
            .onChange(of: settingsViewModel.selectedOptions) { _, newValue in
                Task {
                    await viewModel.syncReminderOptions(
                        settingsViewModel.effectiveReminderOptions,
                        hour: settingsViewModel.reminderHour,
                        minute: settingsViewModel.reminderMinute
                    )
                }
            }
            .onChange(of: settingsViewModel.isPushNotificationsEnabled) { _, _ in
                Task {
                    await viewModel.syncReminderOptions(
                        settingsViewModel.effectiveReminderOptions,
                        hour: settingsViewModel.reminderHour,
                        minute: settingsViewModel.reminderMinute
                    )
                }
            }
            .onChange(of: settingsViewModel.reminderTime) { _, _ in
                Task {
                    await viewModel.syncReminderOptions(
                        settingsViewModel.effectiveReminderOptions,
                        hour: settingsViewModel.reminderHour,
                        minute: settingsViewModel.reminderMinute
                    )
                }
            }
            .onChange(of: viewModel.subscriptions) { _, newValue in
                let currentIDs = Set(newValue.map(\.id))
                selectedSubscriptionIDs = selectedSubscriptionIDs.intersection(currentIDs)
                syncCustomSortOrder(with: newValue)
            }
            .onChange(of: selectedSort) { _, newValue in
                selectedSortStorage = newValue.rawValue
                if newValue != .custom {
                    isCustomSortEditing = false
                }
            }
            .onChange(of: viewModel.selectedFilter) { _, newValue in
                selectedFilterStorage = newValue.rawValue
            }
            .sheet(item: $editorSheet) { sheet in
                ServiceEditorView(original: sheet.originalSubscription) { payload in
                    viewModel.setReminderOptions(Array(settingsViewModel.effectiveReminderOptions))
                    viewModel.setReminderTime(
                        hour: settingsViewModel.reminderHour,
                        minute: settingsViewModel.reminderMinute
                    )
                    await viewModel.upsert(payload)
                    await settingsViewModel.autoBackupAfterSubscriptionUpsert()
                }
            }
            .sheet(isPresented: $isPresentingBulkDateSheet) {
                bulkDateSheet
            }
            .sheet(item: $quickIconTarget) { subscription in
                quickIconSheet(for: subscription)
            }
            .safeAreaInset(edge: .bottom) {
                if displayMode == .board && isSelectionMode && !selectedSubscriptionIDs.isEmpty {
                    bulkActionBar
                }
            }
            .alert("common.error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.errorMessage = nil }
                }
            )) {
                Button("common.confirm", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                } else {
                    Text("common.unknownError")
                }
            }
            .alert(
                "board.delete.confirm.title",
                isPresented: Binding(
                    get: { pendingDeleteSubscription != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeleteSubscription = nil }
                    }
                )
            ) {
                Button("common.delete", role: .destructive) {
                    guard let subscription = pendingDeleteSubscription else { return }
                    Task { await viewModel.delete(subscription) }
                    pendingDeleteSubscription = nil
                }
                Button("common.cancel", role: .cancel) {
                    pendingDeleteSubscription = nil
                }
            } message: {
                Text("board.delete.confirm.single.message")
            }
            .alert("board.delete.confirm.title", isPresented: $isPresentingBulkDeleteConfirmation) {
                Button("common.delete", role: .destructive) {
                    let ids = pendingBulkDeleteIDs
                    Task {
                        await viewModel.delete(ids: ids)
                        await MainActor.run {
                            selectedSubscriptionIDs.removeAll()
                            isSelectionMode = false
                            pendingBulkDeleteIDs.removeAll()
                        }
                    }
                }
                Button("common.cancel", role: .cancel) {
                    pendingBulkDeleteIDs.removeAll()
                }
            } message: {
                Text(
                    String.localizedStringWithFormat(
                        NSLocalizedString("board.delete.confirm.bulk.message", comment: ""),
                        pendingBulkDeleteIDs.count
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: PayBoardSpacing.sm) {
            if boardSubscriptions.isEmpty {
                Text("board.filter.empty")
                    .font(.footnote)
                    .foregroundStyle(Color.payMuted)
                    .padding(.horizontal, PayBoardSpacing.xs)
            } else {
                LazyVGrid(columns: columns, spacing: PayBoardSpacing.md) {
                    ForEach(boardSubscriptions) { subscription in
                        SubscriptionCardView(
                            subscription: subscription,
                            presetIcon: presetIcon(for: subscription.iconKey),
                            showIcon: !isSmallBoardLayout,
                            showDateBelowLabel: isSmallBoardLayout,
                            onTapIcon: isSelectionMode || isCustomDnDEnabled ? nil : {
                                suppressCardTapSubscriptionID = subscription.id
                                quickIconQuery = ""
                                quickIconTarget = subscription
                                DispatchQueue.main.async {
                                    suppressCardTapSubscriptionID = nil
                                }
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelectionMode {
                                Image(systemName: selectedSubscriptionIDs.contains(subscription.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(selectedSubscriptionIDs.contains(subscription.id) ? Color.payAccent : Color.payMuted.opacity(0.8))
                                    .padding(PayBoardSpacing.xs)
                            } else if !isSmallBoardLayout && !isCustomDnDEnabled {
                                cardActionMenu(for: subscription, isCompact: isNormalBoardLayout)
                                    .padding(PayBoardSpacing.xs)
                            }
                        }
                        .onDrag {
                            guard isCustomDnDEnabled else { return NSItemProvider() }
                            draggedCustomSortID = subscription.id
                            return NSItemProvider(object: subscription.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: SubscriptionReorderDropDelegate(
                            targetID: subscription.id,
                            orderedIDs: $customSortOrderIDs,
                            draggedID: $draggedCustomSortID,
                            isEnabled: isCustomDnDEnabled,
                            onPersist: persistCustomSortOrder
                        ))
                        .contentShape(RoundedRectangle(cornerRadius: PayBoardRadius.card))
                        .onTapGesture {
                            if suppressCardTapSubscriptionID == subscription.id { return }
                            if isCustomDnDEnabled { return }
                            if isSelectionMode {
                                toggleSelection(for: subscription.id)
                            } else {
                                editorSheet = .edit(subscription)
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.35) {
                            if isCustomDnDEnabled { return }
                            if !isSelectionMode {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSelectionMode = true
                                }
                            }
                            toggleSelection(for: subscription.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: PayBoardSpacing.sm) {
            VStack(alignment: .leading, spacing: PayBoardSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: PayBoardSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("board.dashboard.thisMonthTotal")
                            .font(.caption)
                            .foregroundStyle(Color.payMuted)
                        Text(formattedMonthlyTotal)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: isDashboardExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.payMuted)
                }

                if isDashboardExpanded {
                    Divider()
                    Text("board.dashboard.categorySummary")
                        .font(.caption)
                        .foregroundStyle(Color.payMuted)

                    if categoryTotals.isEmpty {
                        Text("board.dashboard.empty")
                            .font(.footnote)
                            .foregroundStyle(Color.payMuted)
                    } else {
                        VStack(spacing: PayBoardSpacing.xs) {
                            ForEach(categoryTotals) { entry in
                                HStack {
                                    Text(LocalizedStringKey(entry.category.labelKey))
                                        .font(.subheadline)
                                    Spacer()
                                    Text(formattedCurrency(entry.amount, currencyCode: monthlyCurrencyCode))
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PayBoardRadius.card))
            .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDashboardExpanded.toggle()
                    }
                }
            .padding(PayBoardSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.payCard)
            .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.card))
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: PayBoardSpacing.sm) {
            Text("board.calendar.title")
                .font(.headline)

            VStack(spacing: PayBoardSpacing.sm) {
                HStack(spacing: PayBoardSpacing.sm) {
                    Button {
                        selectedYear = Calendar.current.component(.year, from: displayedMonthStart)
                        selectedMonth = Calendar.current.component(.month, from: displayedMonthStart)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresentingMonthSelector.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(monthTitle(for: displayedMonthStart))
                                .font(.headline.weight(.semibold))
                            Image(systemName: isPresentingMonthSelector ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, PayBoardSpacing.md)
                        .padding(.vertical, PayBoardSpacing.xs)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PayBoardSpacing.xs)

                if isPresentingMonthSelector {
                    inlineMonthPicker
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: PayBoardSpacing.sm) {
                    ForEach(weekdayLabelKeys, id: \.self) { weekdayKey in
                        Text(LocalizedStringKey(weekdayKey))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.payMuted)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(calendarDays) { day in
                        Button {
                            selectedCalendarDate = day.date
                            displayedMonth = monthStart(for: day.date)
                            syncMonthSelectionState()
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day.day)")
                                    .font(.subheadline.weight(day.isSelected ? .semibold : .regular))
                                    .foregroundStyle(dayTextColor(for: day))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(day.isSelected ? Color.payAccent.opacity(0.22) : Color.clear)
                                    )
                                if let marker = calendarMarkerByDate[dateKey(for: day.date)] {
                                    Circle()
                                        .fill(marker.dotColor)
                                        .frame(width: 5, height: 5)
                                } else {
                                    Color.clear.frame(width: 5, height: 5)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, PayBoardSpacing.xs)
            }
            .padding(PayBoardSpacing.md)
            .background(Color.payCard)
            .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.card))

            if selectedDateSubscriptions.isEmpty {
                Text("board.calendar.emptyForDate")
                    .font(.footnote)
                    .foregroundStyle(Color.payMuted)
            } else {
                VStack(spacing: PayBoardSpacing.xs) {
                    ForEach(selectedDateSubscriptions) { subscription in
                        Button {
                            editorSheet = .edit(subscription)
                        } label: {
                            HStack(spacing: PayBoardSpacing.sm) {
                                calendarIconView(for: subscription)
                                    .frame(width: 18, height: 18)
                                    .padding(PayBoardSpacing.xs)
                                    .background(Color.payCard)
                                    .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control))
                                Text(subscription.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Spacer()
                                if let urgency = billingUrgency(for: subscription) {
                                    Image(systemName: urgency.symbolName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(urgency.color)
                                }
                                Text(amountText(for: subscription))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }
                            .padding(PayBoardSpacing.sm)
                            .background(Color.payCard)
                            .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var headerRow: some View {
        VStack(spacing: PayBoardSpacing.sm) {
            HStack(spacing: PayBoardSpacing.sm) {
                Text("board.title")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                Spacer()

                if displayMode == .board {
                    if selectedSort == .custom {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCustomSortEditing.toggle()
                            }
                            if isCustomSortEditing {
                                selectedSubscriptionIDs.removeAll()
                                isSelectionMode = false
                            }
                        } label: {
                            Image(systemName: isCustomSortEditing ? "checkmark.circle" : "pencil.circle")
                                .font(.subheadline.weight(.medium))
                                .frame(width: 32, height: 32)
                                .background(Color.payCard)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(Text(isCustomSortEditing ? "board.sort.custom.done" : "board.sort.custom.edit"))
                    }

                    sortMenuButton

                    Menu {
                        ForEach(BoardFilter.allCases) { filter in
                            Button {
                                viewModel.selectedFilter = filter
                            } label: {
                                Text(LocalizedStringKey(filter.titleKey))
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.subheadline.weight(.medium))
                            .frame(width: 32, height: 32)
                            .background(Color.payCard)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("board.filter.picker"))

                    Menu {
                        Button {
                            columnsCount = 3
                        } label: {
                            Text("board.layout.small")
                        }
                        Button {
                            columnsCount = 2
                        } label: {
                            Text("board.layout.normal")
                        }
                        Button {
                            columnsCount = 1
                        } label: {
                            Text("board.layout.max")
                        }
                    } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.subheadline.weight(.medium))
                            .frame(width: 32, height: 32)
                            .background(Color.payCard)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("board.layout.picker"))

                }

            }

            if displayMode == .board {
                HStack(spacing: 0) {
                    HStack(spacing: PayBoardSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.payMuted)
                        TextField("board.search.placeholder", text: $boardSearchQuery)
                            .textFieldStyle(.plain)
                            .focused($isBoardSearchFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                isBoardSearchFocused = false
                            }
                    }
                    .padding(.horizontal, PayBoardSpacing.sm)
                    .padding(.vertical, PayBoardSpacing.sm)
                    .frame(minHeight: 42)
                    .background(Color.payCard)
                    .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control))
                }
            }
        }
        .padding(.horizontal, PayBoardSpacing.lg)
        .padding(.top, PayBoardSpacing.sm)
        .padding(.bottom, PayBoardSpacing.xs)
    }

    private var shouldShowFloatingAddButton: Bool {
        !(displayMode == .board && isSelectionMode)
    }

    private var floatingAddButton: some View {
        Button {
            editorSheet = .create(UUID())
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 52)
                .background(Color.payAccent)
                .foregroundStyle(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.trailing, PayBoardSpacing.lg)
        .padding(.bottom, floatingButtonBottomPadding)
    }

    private var floatingButtonBottomPadding: CGFloat {
        if displayMode == .board && isSelectionMode && !selectedSubscriptionIDs.isEmpty {
            return 86
        }
        return PayBoardSpacing.lg
    }

    private var quickIconResults: [PresetIcon] {
        let allIcons = PresetIconCatalog.all()
        guard !quickIconQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Array(allIcons.prefix(80))
        }
        return Array(PresetIconCatalog.search(quickIconQuery).prefix(80))
    }

    private func quickIconSheet(for subscription: Subscription) -> some View {
        NavigationStack {
            List(quickIconResults) { icon in
                Button {
                    var updated = subscription
                    updated.iconKey = icon.key
                    updated.updatedAt = .now
                    Task {
                        await viewModel.upsert(updated)
                        await settingsViewModel.autoBackupAfterSubscriptionUpsert()
                    }
                    quickIconTarget = nil
                    quickIconQuery = ""
                } label: {
                    HStack(spacing: PayBoardSpacing.md) {
                        quickIconGlyph(for: icon, iconColorKey: subscription.iconColorKey)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(PresetIconCatalog.localizedDisplayName(for: icon))
                                .foregroundStyle(Color.primary)
                        }
                        Spacer()
                        if icon.key == subscription.iconKey {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.payAccent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("board.icon.quick.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        quickIconTarget = nil
                        quickIconQuery = ""
                    }
                }
            }
            .searchable(text: $quickIconQuery, prompt: Text("service_editor.icon.search"))
        }
    }

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: PayBoardSpacing.sm) {
                Text(String.localizedStringWithFormat(NSLocalizedString("board.selection.count", comment: ""), selectedSubscriptionIDs.count))
                    .font(.caption)
                    .foregroundStyle(Color.payMuted)

                Button("common.cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSubscriptionIDs.removeAll()
                        isSelectionMode = false
                    }
                }
                .font(.caption.weight(.semibold))

                Spacer()

                Button("board.bulk.changeDate") {
                    bulkNextBillingDate = selectedSubscriptionIDs.compactMap { id in
                        viewModel.subscriptions.first(where: { $0.id == id })?.nextBillingDate
                    }.min() ?? .now
                    isPresentingBulkDateSheet = true
                }
                .font(.caption.weight(.semibold))

                Button("board.bulk.complete") {
                    let ids = selectedSubscriptionIDs
                    Task {
                        await viewModel.markPaymentComplete(ids: ids)
                        await MainActor.run {
                            selectedSubscriptionIDs.removeAll()
                            isSelectionMode = false
                        }
                    }
                }
                .font(.caption.weight(.semibold))

                Button("board.bulk.delete", role: .destructive) {
                    pendingBulkDeleteIDs = selectedSubscriptionIDs
                    isPresentingBulkDeleteConfirmation = true
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, PayBoardSpacing.lg)
            .padding(.vertical, PayBoardSpacing.sm)
            .background(Color.payCard)
        }
    }

    private var bulkDateSheet: some View {
        NavigationStack {
            Form {
                DatePicker("service_editor.nextBillingDate", selection: $bulkNextBillingDate, displayedComponents: .date)
            }
            .navigationTitle("board.bulk.changeDate")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        isPresentingBulkDateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.confirm") {
                        let ids = selectedSubscriptionIDs
                        let date = bulkNextBillingDate
                        Task {
                            await viewModel.updateNextBillingDate(ids: ids, to: date)
                            await MainActor.run {
                                isPresentingBulkDateSheet = false
                                selectedSubscriptionIDs.removeAll()
                                isSelectionMode = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthSubscriptions: [Subscription] {
        let calendar = Calendar.current
        let now = Date()
        return viewModel.subscriptions.filter { subscription in
            calendar.isDate(subscription.nextBillingDate, equalTo: now, toGranularity: .month)
                && calendar.isDate(subscription.nextBillingDate, equalTo: now, toGranularity: .year)
        }
    }

    private var selectedDateSubscriptions: [Subscription] {
        let calendar = Calendar.current
        return viewModel.subscriptions
            .filter { calendar.isDate($0.nextBillingDate, inSameDayAs: selectedCalendarDate) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var boardSubscriptions: [Subscription] {
        let trimmedQuery = boardSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let loweredQuery = trimmedQuery.lowercased()

        let filtered = viewModel.filteredSubscriptions.filter { subscription in
            guard !loweredQuery.isEmpty else { return true }
            if subscription.name.lowercased().contains(loweredQuery) { return true }
            if let customCategoryName = subscription.customCategoryName?.lowercased(),
               customCategoryName.contains(loweredQuery) { return true }
            let localizedCategory = NSLocalizedString(subscription.category.labelKey, comment: "").lowercased()
            return localizedCategory.contains(loweredQuery)
        }

        return filtered.sorted { lhs, rhs in
            switch selectedSort {
            case .nextBillingAsc:
                return lhs.nextBillingDate < rhs.nextBillingDate
            case .nextBillingDesc:
                return lhs.nextBillingDate > rhs.nextBillingDate
            case .nameAsc:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .amountDesc:
                return NSDecimalNumber(decimal: lhs.amount).compare(NSDecimalNumber(decimal: rhs.amount)) == .orderedDescending
            case .custom:
                let leftOrder = customSortOrderIndexMap[lhs.id] ?? Int.max
                let rightOrder = customSortOrderIndexMap[rhs.id] ?? Int.max
                if leftOrder == rightOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return leftOrder < rightOrder
            }
        }
    }

    private var monthlyCurrencyCode: String {
        monthSubscriptions.first?.currencyCode ?? "KRW"
    }

    private var monthlyTotal: Decimal {
        monthSubscriptions.reduce(Decimal.zero) { partial, subscription in
            partial + subscription.amount
        }
    }

    private var formattedMonthlyTotal: String {
        formattedCurrency(monthlyTotal, currencyCode: monthlyCurrencyCode)
    }

    private var categoryTotals: [CategoryTotal] {
        let grouped = Dictionary(grouping: monthSubscriptions, by: \.category)
        return grouped.map { category, subscriptions in
            let amount = subscriptions.reduce(Decimal.zero) { partial, subscription in
                partial + subscription.amount
            }
            return CategoryTotal(category: category, amount: amount)
        }
        .sorted { lhs, rhs in
            NSDecimalNumber(decimal: lhs.amount).compare(NSDecimalNumber(decimal: rhs.amount)) == .orderedDescending
        }
    }

    private var sanitizedColumnsCount: Int {
        min(3, max(1, columnsCount))
    }

    private func restorePersistedViewStateIfNeeded() {
        guard !hasRestoredPersistedViewState else { return }
        hasRestoredPersistedViewState = true

        if let restoredSort = BoardSortOption(rawValue: selectedSortStorage) {
            selectedSort = restoredSort
        }
        if let restoredFilter = BoardFilter(rawValue: selectedFilterStorage) {
            viewModel.selectedFilter = restoredFilter
        }

        let sanitized = sanitizedColumnsCount
        if columnsCount != sanitized {
            columnsCount = sanitized
        }
    }

    private var isSmallBoardLayout: Bool {
        displayMode == .board && sanitizedColumnsCount == 3
    }

    private var isNormalBoardLayout: Bool {
        displayMode == .board && sanitizedColumnsCount == 2
    }

    private var customSortOrderIndexMap: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: customSortOrderIDs.enumerated().map { ($1, $0) })
    }

    private var isCustomDnDEnabled: Bool {
        displayMode == .board && selectedSort == .custom && isCustomSortEditing && !isSelectionMode
    }

    private func toggleSelection(for id: UUID) {
        if selectedSubscriptionIDs.contains(id) {
            selectedSubscriptionIDs.remove(id)
            if selectedSubscriptionIDs.isEmpty {
                isSelectionMode = false
            }
        } else {
            selectedSubscriptionIDs.insert(id)
            if !isSelectionMode {
                isSelectionMode = true
            }
        }
    }

    private func loadCustomSortOrderIfNeeded() {
        guard !hasLoadedCustomSortOrder else { return }
        customSortOrderIDs = customSortOrderStorage
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        hasLoadedCustomSortOrder = true
    }

    private func syncCustomSortOrder(with subscriptions: [Subscription]) {
        loadCustomSortOrderIfNeeded()
        let subscriptionIDs = subscriptions.map(\.id)
        let subscriptionIDSet = Set(subscriptionIDs)
        customSortOrderIDs = customSortOrderIDs.filter { subscriptionIDSet.contains($0) }
        for id in subscriptionIDs where !customSortOrderIDs.contains(id) {
            customSortOrderIDs.append(id)
        }
        persistCustomSortOrder()
    }

    private func persistCustomSortOrder() {
        customSortOrderStorage = customSortOrderIDs.map(\.uuidString).joined(separator: ",")
    }

    private var sortMenuButton: some View {
        Menu {
            ForEach(BoardSortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    if selectedSort == option {
                        Label(LocalizedStringKey(option.titleKey), systemImage: "checkmark")
                    } else {
                        Text(LocalizedStringKey(option.titleKey))
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.medium))
                .frame(width: 32, height: 32)
                .background(Color.payCard)
                .clipShape(Circle())
        }
        .accessibilityLabel(Text("board.sort.title"))
    }

    private func cardActionMenu(for subscription: Subscription, isCompact: Bool = false) -> some View {
        Menu {
            Button("common.edit") {
                editorSheet = .edit(subscription)
            }
            Button("board.action.completePayment") {
                Task { await viewModel.markPaymentComplete(subscription) }
            }
            Button("common.delete", role: .destructive) {
                pendingDeleteSubscription = subscription
            }
        } label: {
            Image(systemName: "ellipsis")
                .font((isCompact ? Font.subheadline : Font.title3).weight(.bold))
                .foregroundStyle(Color.primary.opacity(0.88))
                .frame(width: isCompact ? 16 : 18, height: isCompact ? 16 : 18)
                .padding(isCompact ? 8 : 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var displayedMonthStart: Date {
        monthStart(for: displayedMonth)
    }

    private var weekdayLabelKeys: [String] {
        let calendar = Calendar.current
        var symbols = [
            "board.calendar.weekday.sun",
            "board.calendar.weekday.mon",
            "board.calendar.weekday.tue",
            "board.calendar.weekday.wed",
            "board.calendar.weekday.thu",
            "board.calendar.weekday.fri",
            "board.calendar.weekday.sat"
        ]
        let shift = max(0, min(6, calendar.firstWeekday - 1))
        if shift > 0 {
            symbols = Array(symbols[shift...]) + Array(symbols[..<shift])
        }
        return symbols
    }

    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthStart),
              let daysRange = calendar.range(of: .day, in: .month, for: displayedMonthStart) else {
            return []
        }

        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        var items: [CalendarDay] = []

        for offset in stride(from: leadingCount, to: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: firstDayOfMonth) {
                items.append(makeCalendarDay(date: date, isCurrentMonth: false))
            }
        }

        for day in daysRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                items.append(makeCalendarDay(date: date, isCurrentMonth: true))
            }
        }

        let trailingCount = (7 - (items.count % 7)) % 7
        if trailingCount > 0, let lastCurrentDate = items.last?.date {
            for offset in 1...trailingCount {
                if let date = calendar.date(byAdding: .day, value: offset, to: lastCurrentDate) {
                    items.append(makeCalendarDay(date: date, isCurrentMonth: false))
                }
            }
        }

        return items
    }

    private var calendarMarkerByDate: [String: CalendarMarker] {
        var result: [String: CalendarMarker] = [:]
        let calendar = Calendar.current

        for subscription in viewModel.subscriptions {
            if calendar.isDate(subscription.nextBillingDate, equalTo: displayedMonthStart, toGranularity: .month) {
                let key = dateKey(for: subscription.nextBillingDate)
                let nextMarker: CalendarMarker
                if let urgency = billingUrgency(for: subscription) {
                    switch urgency {
                    case .warning:
                        nextMarker = .warning
                    case .critical:
                        nextMarker = .critical
                    }
                } else {
                    nextMarker = .scheduled
                }
                if let existing = result[key] {
                    result[key] = existing.priority >= nextMarker.priority ? existing : nextMarker
                } else {
                    result[key] = nextMarker
                }
            }

            if let lastPaymentDate = subscription.lastPaymentDate,
               calendar.isDate(lastPaymentDate, equalTo: displayedMonthStart, toGranularity: .month) {
                let key = dateKey(for: lastPaymentDate)
                if let existing = result[key] {
                    result[key] = existing.priority >= CalendarMarker.paid.priority ? existing : .paid
                } else {
                    result[key] = .paid
                }
            }
        }
        return result
    }

    private func presetIcon(for iconKey: String) -> PresetIcon? {
        PresetIconCatalog.icon(for: iconKey)
    }

    private func formattedCurrency(_ amount: Decimal, currencyCode: String) -> String {
        if currencyCode.uppercased() == "KRW" {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let value = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            return value + NSLocalizedString("currency.krw.suffix", comment: "")
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    private func amountText(for subscription: Subscription) -> String {
        if subscription.isAmountUndecided {
            return NSLocalizedString("common.variable", comment: "")
        }
        return formattedCurrency(subscription.amount, currencyCode: subscription.currencyCode)
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settingsViewModel.preferredLocale
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: date)
    }

    private func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func moveMonth(by value: Int) {
        let calendar = Calendar.current
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonthStart) ?? displayedMonthStart
        syncMonthSelectionState()
    }

    private var availableYearRange: ClosedRange<Int> {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let years = viewModel.subscriptions.map { calendar.component(.year, from: $0.nextBillingDate) }
        let minYear = min(years.min() ?? currentYear, currentYear - 5)
        let maxYear = max(years.max() ?? currentYear, currentYear + 5)
        return minYear...maxYear
    }

    private var inlineMonthPicker: some View {
        HStack(spacing: 0) {
            Picker("board.calendar.select.year", selection: $selectedYear) {
                ForEach(Array(availableYearRange), id: \.self) { year in
                    Text(verbatim: yearPickerLabel(year)).tag(year)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("board.calendar.select.month", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(verbatim: monthPickerLabel(month)).tag(month)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #endif
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 180)
        .background(Color.payBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: PayBoardRadius.control))
        .onChange(of: selectedYear) { _, _ in
            applyMonthSelection()
        }
        .onChange(of: selectedMonth) { _, _ in
            applyMonthSelection()
        }
    }

    private func syncMonthSelectionState() {
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: displayedMonthStart)
        selectedMonth = calendar.component(.month, from: displayedMonthStart)
    }

    private func applyMonthSelection() {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            displayedMonth = date
            selectedCalendarDate = date
        }
    }

    private func yearPickerLabel(_ year: Int) -> String {
        if settingsViewModel.preferredLocale.identifier.hasPrefix("ko") {
            return "\(year)년"
        }
        return "\(year)"
    }

    private func monthPickerLabel(_ month: Int) -> String {
        if settingsViewModel.preferredLocale.identifier.hasPrefix("ko") {
            return "\(month)월"
        }
        return "\(month)"
    }

    private func makeCalendarDay(date: Date, isCurrentMonth: Bool) -> CalendarDay {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return CalendarDay(
            date: date,
            day: day,
            isCurrentMonth: isCurrentMonth,
            isSelected: calendar.isDate(date, inSameDayAs: selectedCalendarDate),
            isToday: calendar.isDateInToday(date)
        )
    }

    private func dayTextColor(for day: CalendarDay) -> Color {
        if day.isSelected {
            return .payAccent
        }
        if !day.isCurrentMonth {
            return Color.payMuted.opacity(0.55)
        }
        if day.isToday {
            return .payAccent
        }
        return .primary
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private func billingUrgency(for subscription: Subscription) -> BillingUrgency? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let billingDay = calendar.startOfDay(for: subscription.nextBillingDate)
        let days = calendar.dateComponents([.day], from: today, to: billingDay).day ?? Int.max
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return nil
    }

    @ViewBuilder
    private func calendarIconView(for subscription: Subscription) -> some View {
        if let presetIcon = presetIcon(for: subscription.iconKey),
           let assetName = presetIcon.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: presetIcon(for: subscription.iconKey)?.systemSymbol ?? "app.badge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.payIconTint(for: subscription.iconColorKey))
        }
    }

    @ViewBuilder
    private func quickIconGlyph(for icon: PresetIcon, iconColorKey: String) -> some View {
        if let assetName = icon.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: icon.systemSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.payIconTint(for: iconColorKey))
        }
    }

    private enum EditorSheet: Identifiable {
        case create(UUID)
        case edit(Subscription)

        var id: String {
            switch self {
            case let .create(token):
                return "create-\(token.uuidString)"
            case let .edit(subscription):
                return "edit-\(subscription.id.uuidString)"
            }
        }

        var originalSubscription: Subscription? {
            switch self {
            case .create:
                return nil
            case let .edit(subscription):
                return subscription
            }
        }
    }

    private struct CategoryTotal: Identifiable {
        let category: SubscriptionCategory
        let amount: Decimal
        var id: SubscriptionCategory { category }
    }

    private struct CalendarDay: Identifiable {
        var id: String { "\(day)-\(isCurrentMonth)-\(date.timeIntervalSince1970)" }
        let date: Date
        let day: Int
        let isCurrentMonth: Bool
        let isSelected: Bool
        let isToday: Bool
    }

    private enum BoardSortOption: String, CaseIterable, Identifiable {
        case nextBillingAsc
        case nextBillingDesc
        case nameAsc
        case amountDesc
        case custom

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .nextBillingAsc:
                return "board.sort.nextBillingAsc"
            case .nextBillingDesc:
                return "board.sort.nextBillingDesc"
            case .nameAsc:
                return "board.sort.nameAsc"
            case .amountDesc:
                return "board.sort.amountDesc"
            case .custom:
                return "board.sort.custom"
            }
        }
    }

    private struct SubscriptionReorderDropDelegate: DropDelegate {
        let targetID: UUID
        @Binding var orderedIDs: [UUID]
        @Binding var draggedID: UUID?
        let isEnabled: Bool
        let onPersist: () -> Void

        func dropEntered(info: DropInfo) {
            guard isEnabled,
                  let draggedID,
                  draggedID != targetID,
                  let sourceIndex = orderedIDs.firstIndex(of: draggedID),
                  let targetIndex = orderedIDs.firstIndex(of: targetID) else {
                return
            }

            withAnimation(.easeInOut(duration: 0.15)) {
                orderedIDs.move(
                    fromOffsets: IndexSet(integer: sourceIndex),
                    toOffset: sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
                )
            }
            onPersist()
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            isEnabled ? DropProposal(operation: .move) : DropProposal(operation: .copy)
        }

        func performDrop(info: DropInfo) -> Bool {
            guard isEnabled else { return false }
            draggedID = nil
            onPersist()
            return true
        }
    }

    private enum CalendarMarker {
        case scheduled
        case warning
        case critical
        case paid

        var dotColor: Color {
            switch self {
            case .scheduled:
                return Color.payAccent.opacity(0.85)
            case .warning:
                return Color.yellow.opacity(0.95)
            case .critical:
                return Color.red.opacity(0.95)
            case .paid:
                return Color.green.opacity(0.95)
            }
        }

        var priority: Int {
            switch self {
            case .scheduled:
                return 0
            case .warning:
                return 1
            case .critical:
                return 2
            case .paid:
                return 3
            }
        }
    }

    private enum BillingUrgency {
        case warning
        case critical

        var symbolName: String {
            switch self {
            case .warning:
                return "exclamationmark.triangle.fill"
            case .critical:
                return "exclamationmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .warning:
                return .yellow
            case .critical:
                return .red
            }
        }

        var dotColor: Color {
            switch self {
            case .warning:
                return Color.yellow.opacity(0.95)
            case .critical:
                return Color.red.opacity(0.95)
            }
        }

        var priority: Int {
            switch self {
            case .warning:
                return 1
            case .critical:
                return 2
            }
        }
    }
}

#Preview("Board") {
    BoardPreviewContainer()
}

private struct BoardPreviewContainer: View {
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var boardViewModel: BoardViewModel

    init() {
        let settings = SettingsViewModel(scheduler: NoopNotificationScheduler())
        _settingsViewModel = StateObject(wrappedValue: settings)
        _boardViewModel = StateObject(
            wrappedValue: BoardViewModel(
                repository: InMemorySubscriptionRepository(seed: SampleData.subscriptions),
                notificationScheduler: NoopNotificationScheduler()
            )
        )
    }

    var body: some View {
        BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel)
            .task {
                await boardViewModel.onAppear()
            }
    }
}
