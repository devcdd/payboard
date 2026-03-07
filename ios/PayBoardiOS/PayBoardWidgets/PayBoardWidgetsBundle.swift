import AppIntents
import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

private enum WidgetSharedStore {
    nonisolated static let appGroupID = "group.kr.co.cdd.PayBoardiOS"
    nonisolated static let dataKey = "widget.snapshot.subscriptions.v1"

    nonisolated static func subscriptions() -> [WidgetSubscription] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: dataKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetSubscription].self, from: data)) ?? []
    }
}

private struct WidgetSubscription: Codable, Identifiable {
    let id: String
    let name: String
    let nextBillingDate: Date
    let amount: Double
    let currencyCode: String
    let isAmountUndecided: Bool
    let iconAssetName: String?
    let iconSystemSymbol: String?
    let iconColorKey: String?
    let iconPNGData: Data?
}

private struct EarliestThreeEntry: TimelineEntry {
    let date: Date
    let subscriptions: [WidgetSubscription]
}

private struct EarliestThreeProvider: TimelineProvider {
    func placeholder(in context: Context) -> EarliestThreeEntry {
        EarliestThreeEntry(date: .now, subscriptions: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (EarliestThreeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EarliestThreeEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> EarliestThreeEntry {
        let subscriptions = WidgetSharedStore.subscriptions()
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
        return EarliestThreeEntry(date: .now, subscriptions: Array(subscriptions.prefix(3)))
    }
}

private struct EarliestThreeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EarliestThreeEntry

    private func iconTintColor(for key: String?) -> Color {
        switch key {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray": return .gray
        default: return .blue
        }
    }

    @ViewBuilder
    private func subscriptionIcon(_ item: WidgetSubscription) -> some View {
        if let pngData = item.iconPNGData,
           let iconImage = imageFromPNGData(pngData) {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else if let asset = item.iconAssetName,
           !asset.isEmpty,
           imageAssetExists(asset) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: item.iconSystemSymbol ?? "app.badge")
                .font(.caption.weight(.semibold))
                .frame(width: 18, height: 18)
                .foregroundStyle(iconTintColor(for: item.iconColorKey))
        }
    }

    private func imageAssetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name, in: .main, compatibleWith: nil) != nil
        #else
        return false
        #endif
    }

    private func imageFromPNGData(_ data: Data) -> UIImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #else
        return nil
        #endif
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private func indicatorColor(for date: Date) -> Color? {
        let day = Calendar.current.startOfDay(for: date)
        let diff = Calendar.current.dateComponents([.day], from: startOfToday, to: day).day ?? Int.max
        if diff <= 1 { return .red.opacity(0.95) }
        if diff <= 3 { return .yellow.opacity(0.95) }
        return nil
    }

    @ViewBuilder
    private func indicatorDot(for date: Date) -> some View {
        if let color = indicatorColor(for: date) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        } else {
            Color.clear
                .frame(width: 8, height: 8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if family != .systemSmall {
                Text("다가오는 결제 3개")
                    .font(.headline)
                    .padding(.bottom, 12)
            }
            if entry.subscriptions.isEmpty {
                Text("표시할 항목이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.subscriptions) { item in
                        HStack {
                            subscriptionIcon(item)
                            Text(item.name)
                                .lineLimit(1)
                            Spacer()
                            if family != .systemSmall {
                                Text(item.nextBillingDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            indicatorDot(for: item.nextBillingDate)
                        }
                    }
                }
            }
        }
        .padding(.top, family == .systemSmall ? -2 : -6)
        .padding(.bottom, 1)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct EarliestThreeWidget: Widget {
    let kind: String = "EarliestThreeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EarliestThreeProvider()) { entry in
            EarliestThreeWidgetView(entry: entry)
        }
        .configurationDisplayName("빠른 결제 3개")
        .description("결제일이 가장 빠른 3개 항목을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SubscriptionEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "정기결제 항목"
    static var defaultQuery: SubscriptionEntityQuery = .init()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct SubscriptionEntityQuery: EntityQuery {
    func entities(for identifiers: [SubscriptionEntity.ID]) async throws -> [SubscriptionEntity] {
        WidgetSharedStore.subscriptions()
            .filter { identifiers.contains($0.id) }
            .map { SubscriptionEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [SubscriptionEntity] {
        WidgetSharedStore.subscriptions()
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
            .map { SubscriptionEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectedSubscriptionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "정기결제 선택"
    static var description = IntentDescription("하나의 정기결제 항목을 선택해 표시합니다.")

    @Parameter(title: "정기결제 항목")
    var subscription: SubscriptionEntity?
}

private struct SelectedSubscriptionEntry: TimelineEntry {
    let date: Date
    let subscription: WidgetSubscription?
}

private struct SelectedSubscriptionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SelectedSubscriptionEntry {
        SelectedSubscriptionEntry(date: .now, subscription: nil)
    }

    func snapshot(for configuration: SelectedSubscriptionIntent, in context: Context) async -> SelectedSubscriptionEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectedSubscriptionIntent, in context: Context) async -> Timeline<SelectedSubscriptionEntry> {
        let entry = makeEntry(configuration: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func makeEntry(configuration: SelectedSubscriptionIntent) -> SelectedSubscriptionEntry {
        let selectedID = configuration.subscription?.id
        let subscription = WidgetSharedStore.subscriptions().first { $0.id == selectedID }
        return SelectedSubscriptionEntry(date: .now, subscription: subscription)
    }
}

private struct SelectedSubscriptionWidgetView: View {
    let entry: SelectedSubscriptionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("선택한 정기결제")
                .font(.headline)
            if let item = entry.subscription {
                Text(item.name)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("다음 결제일: \(item.nextBillingDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("항목을 선택해 주세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SelectedSubscriptionWidget: Widget {
    let kind: String = "SelectedSubscriptionWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectedSubscriptionIntent.self,
            provider: SelectedSubscriptionProvider()
        ) { entry in
            SelectedSubscriptionWidgetView(entry: entry)
        }
        .configurationDisplayName("단일 항목 위젯")
        .description("선택한 정기결제 항목 하나를 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct CalendarEntry: TimelineEntry {
    let date: Date
    let monthStart: Date
    let markedDays: Set<Int>
}

private struct WeekRangeEntry: TimelineEntry {
    let date: Date
    let startOfWeek: Date
    let weekCount: Int
    let markedDates: Set<Date>
}

private struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, monthStart: monthStart(from: .now), markedDays: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> CalendarEntry {
        let calendar = Calendar.current
        let start = monthStart(from: .now)
        let subscriptions = WidgetSharedStore.subscriptions()
        let marked = Set(subscriptions.compactMap { subscription -> Int? in
            guard calendar.isDate(subscription.nextBillingDate, equalTo: start, toGranularity: .month),
                  calendar.isDate(subscription.nextBillingDate, equalTo: start, toGranularity: .year) else {
                return nil
            }
            return calendar.component(.day, from: subscription.nextBillingDate)
        })
        return CalendarEntry(date: .now, monthStart: start, markedDays: marked)
    }

    private func monthStart(from date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct WeekRangeProvider: TimelineProvider {
    let weekCount: Int

    func placeholder(in context: Context) -> WeekRangeEntry {
        WeekRangeEntry(date: .now, startOfWeek: startOfWeek(from: .now), weekCount: weekCount, markedDates: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekRangeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekRangeEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> WeekRangeEntry {
        let calendar = Calendar.current
        let start = startOfWeek(from: .now)
        let end = calendar.date(byAdding: .day, value: (weekCount * 7) - 1, to: start) ?? start
        let markedDates = Set(
            WidgetSharedStore.subscriptions()
                .map { calendar.startOfDay(for: $0.nextBillingDate) }
                .filter { $0 >= start && $0 <= end }
        )
        return WeekRangeEntry(date: .now, startOfWeek: start, weekCount: weekCount, markedDates: markedDates)
    }

    private func startOfWeek(from date: Date) -> Date {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return calendar.startOfDay(for: interval.start)
        }
        return calendar.startOfDay(for: date)
    }
}

private enum WidgetCalendarStyle {
    static let widgetBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let weekday = Color.white.opacity(0.70)
    static let dayText = Color.white.opacity(0.94)
    static let accent = Color(red: 0.04, green: 0.47, blue: 0.83)
    static let selectedFill = accent.opacity(0.22)
    static let markerDot = accent.opacity(0.85)
}

private func koreanWeekdaySymbols(firstWeekday: Int) -> [String] {
    let base = ["일", "월", "화", "수", "목", "금", "토"]
    let shift = max(0, min(6, firstWeekday - 1))
    if shift == 0 { return base }
    return Array(base[shift...]) + Array(base[..<shift])
}

private struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarEntry

    private var weekdaySymbols: [String] {
        koreanWeekdaySymbols(firstWeekday: Calendar.current.firstWeekday)
    }

    private var dayCells: [Int?] {
        let calendar = Calendar.current
        guard let daysRange = calendar.range(of: .day, in: .month, for: entry.monthStart) else {
            return Array(repeating: nil, count: 42)
        }

        let firstDayWeekday = calendar.component(.weekday, from: entry.monthStart)
        let leading = (firstDayWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: daysRange.map { Optional($0) })
        cells.append(contentsOf: Array(repeating: nil, count: max(0, 42 - cells.count)))
        return Array(cells.prefix(42))
    }

    private var isCurrentMonthToday: Bool {
        let calendar = Calendar.current
        return calendar.isDate(entry.monthStart, equalTo: .now, toGranularity: .month)
            && calendar.isDate(entry.monthStart, equalTo: .now, toGranularity: .year)
    }

    private var todayDayNumber: Int? {
        guard isCurrentMonthToday else { return nil }
        return Calendar.current.component(.day, from: .now)
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = family == .systemLarge ? 8 : 6
            let availableHeight = proxy.size.height - (spacing * 6)
            let rowHeight = max(family == .systemLarge ? 36 : 24, availableHeight / 7)
            let circleSize = family == .systemLarge ? 28.0 : 22.0

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7), spacing: spacing) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetCalendarStyle.weekday)
                        .frame(maxWidth: .infinity, minHeight: rowHeight * 0.7)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isToday = todayDayNumber == day
                        VStack(spacing: 2) {
                            Text("\(day)")
                                .font((family == .systemLarge ? Font.subheadline : Font.caption).weight(isToday ? .semibold : .regular))
                                .foregroundStyle(isToday ? WidgetCalendarStyle.accent : WidgetCalendarStyle.dayText)
                                .frame(width: circleSize, height: circleSize)
                                .background(
                                    Circle()
                                        .fill(isToday ? WidgetCalendarStyle.selectedFill : Color.clear)
                                )
                            if entry.markedDays.contains(day) {
                                Circle()
                                    .fill(WidgetCalendarStyle.markerDot)
                                    .frame(width: 5, height: 5)
                            } else {
                                Color.clear
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: rowHeight)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: rowHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(WidgetCalendarStyle.widgetBackground, for: .widget)
    }
}

private struct WeekRangeCalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeekRangeEntry

    private var weekdaySymbols: [String] {
        koreanWeekdaySymbols(firstWeekday: Calendar.current.firstWeekday)
    }

    private var days: [Date] {
        let calendar = Calendar.current
        return (0..<(entry.weekCount * 7)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: entry.startOfWeek)
        }
    }

    private var weekRows: [[Date]] {
        stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: .now)
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = family == .systemSmall ? 4 : 6
            let totalRows = CGFloat(entry.weekCount + 1)
            let availableHeight = proxy.size.height - (spacing * (totalRows - 1))
            let rowHeight = max(family == .systemSmall ? 18 : 22, availableHeight / totalRows)
            let circleSize = family == .systemSmall ? 20.0 : 24.0

            VStack(spacing: spacing) {
                HStack(spacing: 4) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WidgetCalendarStyle.weekday)
                            .frame(maxWidth: .infinity, minHeight: rowHeight * 0.8)
                    }
                }

                ForEach(Array(weekRows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            let dayKey = Calendar.current.startOfDay(for: day)
                            let isToday = isToday(day)
                            VStack(spacing: 2) {
                                Text(day.formatted(.dateTime.day()))
                                    .font(.caption.weight(isToday ? .semibold : .regular))
                                    .foregroundStyle(isToday ? WidgetCalendarStyle.accent : WidgetCalendarStyle.dayText)
                                    .frame(width: circleSize, height: circleSize)
                                    .background(
                                        Circle()
                                            .fill(isToday ? WidgetCalendarStyle.selectedFill : Color.clear)
                                    )
                                if entry.markedDates.contains(dayKey) {
                                    Circle()
                                        .fill(WidgetCalendarStyle.markerDot)
                                        .frame(width: 5, height: 5)
                                } else {
                                    Color.clear
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: rowHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(WidgetCalendarStyle.widgetBackground, for: .widget)
    }
}

struct TwoWeekPaymentCalendarWidget: Widget {
    let kind: String = "TwoWeekPaymentCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekRangeProvider(weekCount: 2)) { entry in
            WeekRangeCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("2주 결제 캘린더")
        .description("이번 주부터 2주간 결제 예정일을 보여줍니다.")
        .supportedFamilies([.systemMedium])
    }
}

struct ThreeWeekPaymentCalendarWidget: Widget {
    let kind: String = "ThreeWeekPaymentCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekRangeProvider(weekCount: 3)) { entry in
            WeekRangeCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("3주 결제 캘린더")
        .description("이번 주, 다음 주, 다다음 주 결제 예정일을 보여줍니다.")
        .supportedFamilies([.systemMedium])
    }
}

struct PaymentCalendarWidget: Widget {
    let kind: String = "PaymentCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("결제 캘린더")
        .description("이번 달 결제 예정일을 달력으로 보여줍니다.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct PayBoardWidgetsBundle: WidgetBundle {
    var body: some Widget {
        EarliestThreeWidget()
        SelectedSubscriptionWidget()
        TwoWeekPaymentCalendarWidget()
        ThreeWeekPaymentCalendarWidget()
        PaymentCalendarWidget()
    }
}
