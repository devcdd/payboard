import AppIntents
import DesignSystem
import Domain
import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

private enum WidgetSharedStore {
    nonisolated static let appGroupID = "group.kr.co.cdd.PayBoardiOS"
    nonisolated static let dataKey = "widget.snapshot.subscriptions.v1"

    nonisolated static func subscriptions(asOf date: Date = .now) -> [WidgetSubscription] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: dataKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = (try? decoder.decode([WidgetSubscription].self, from: data)) ?? []
        return rows.map { $0.projected(asOf: date) }
    }

    // 앱이 깨어나지 않아도 매일 0시 엔트리에서 결제일과 남은 일수를 다시 계산하도록 일주일치를 미리 만든다
    nonisolated static func dailyEntryDates(from now: Date = .now, days: Int = 7) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return [now] + (1...days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    // 앱 캘린더와 같은 규칙: 다음 결제일은 남은 일수에 따라 색이 바뀌고, 결제 기록이 있는 날은 결제 완료가 우선한다
    nonisolated static func markers(
        for subscriptions: [WidgetSubscription],
        from start: Date,
        to end: Date,
        today: Date
    ) -> [Date: PaymentCalendarMarker] {
        let calendar = Calendar.current
        var result: [Date: PaymentCalendarMarker] = [:]
        for subscription in subscriptions {
            let billingDay = calendar.startOfDay(for: subscription.nextBillingDate)
            if billingDay >= start && billingDay <= end {
                let marker = PaymentCalendarMarker.upcoming(billingDate: billingDay, today: today, calendar: calendar)
                result[billingDay] = marker.merged(with: result[billingDay])
            }
            for paymentDate in subscription.paymentDates ?? [] {
                let paymentDay = calendar.startOfDay(for: paymentDate)
                guard paymentDay >= start && paymentDay <= end else { continue }
                result[paymentDay] = PaymentCalendarMarker.paid.merged(with: result[paymentDay])
            }
        }
        return result
    }
}

private struct WidgetSubscription: Codable, Identifiable {
    let id: String
    let name: String
    var nextBillingDate: Date
    // 이전 버전 앱이 저장한 스냅샷에는 없으므로 optional
    let billingCycle: BillingCycle?
    let billingAnchorDay: Int?
    let autoAdvances: Bool?
    let amount: Double
    let currencyCode: String
    let isAmountUndecided: Bool
    let iconAssetName: String?
    let iconSystemSymbol: String?
    let iconColorKey: String?
    let iconPNGData: Data?
    let paymentDates: [Date]?

    // 앱의 자동결제 처리와 같은 규칙으로, 결제일 당일부터 다음 회차를 보여준다. 실제 결제 기록은 앱이 열릴 때 남긴다
    nonisolated func projected(asOf date: Date, calendar: Calendar = .current) -> WidgetSubscription {
        guard autoAdvances == true, let billingCycle else { return self }
        let today = calendar.startOfDay(for: date)
        var copy = self
        var anchorDay = billingAnchorDay
        while calendar.startOfDay(for: copy.nextBillingDate) <= today {
            anchorDay = BillingDateCalculator.resolvedAnchorDay(for: copy.nextBillingDate, anchorDay: anchorDay, calendar: calendar)
            let next = BillingDateCalculator.advance(from: copy.nextBillingDate, cycle: billingCycle, anchorDay: anchorDay, calendar: calendar)
            guard next > copy.nextBillingDate else { break }
            copy.nextBillingDate = next
        }
        return copy
    }
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
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EarliestThreeEntry>) -> Void) {
        let entries = WidgetSharedStore.dailyEntryDates().map(makeEntry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> EarliestThreeEntry {
        let subscriptions = WidgetSharedStore.subscriptions(asOf: date)
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
        return EarliestThreeEntry(date: date, subscriptions: Array(subscriptions.prefix(3)))
    }
}

private struct EarliestThreeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EarliestThreeEntry

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
                .foregroundStyle(Color.payIconTint(for: item.iconColorKey ?? ""))
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
        Calendar.current.startOfDay(for: entry.date)
    }

    private func indicatorColor(for date: Date) -> Color? {
        let marker = PaymentCalendarMarker.upcoming(billingDate: date, today: startOfToday)
        return marker == .scheduled ? nil : marker.dotColor
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
                    .foregroundStyle(Color.payMuted)
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
                                Text(item.nextBillingDate.koreanDateText)
                                    .font(.caption)
                                    .foregroundStyle(Color.payMuted)
                            }
                            indicatorDot(for: item.nextBillingDate)
                        }
                    }
                }
            }
        }
        .padding(.top, family == .systemSmall ? -2 : -6)
        .padding(.bottom, 1)
        .containerBackground(Color.payCard, for: .widget)
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
        makeEntry(configuration: configuration, at: .now)
    }

    func timeline(for configuration: SelectedSubscriptionIntent, in context: Context) async -> Timeline<SelectedSubscriptionEntry> {
        let entries = WidgetSharedStore.dailyEntryDates().map { makeEntry(configuration: configuration, at: $0) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(configuration: SelectedSubscriptionIntent, at date: Date) -> SelectedSubscriptionEntry {
        let selectedID = configuration.subscription?.id
        let subscription = WidgetSharedStore.subscriptions(asOf: date).first { $0.id == selectedID }
        return SelectedSubscriptionEntry(date: date, subscription: subscription)
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
                Text("다음 결제일: \(item.nextBillingDate.koreanDateText)")
                    .font(.caption)
                    .foregroundStyle(Color.payMuted)
            } else {
                Text("항목을 선택해 주세요")
                    .font(.caption)
                    .foregroundStyle(Color.payMuted)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(Color.payCard, for: .widget)
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
    let markers: [Date: PaymentCalendarMarker]
}

private struct WeekRangeEntry: TimelineEntry {
    let date: Date
    let startOfWeek: Date
    let weekCount: Int
    let markers: [Date: PaymentCalendarMarker]
}

private struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, monthStart: monthStart(from: .now), markers: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let entries = WidgetSharedStore.dailyEntryDates().map(makeEntry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> CalendarEntry {
        let calendar = Calendar.current
        let start = monthStart(from: date)
        let end = calendar.dateInterval(of: .month, for: start).flatMap {
            calendar.date(byAdding: .day, value: -1, to: $0.end)
        } ?? start
        let markers = WidgetSharedStore.markers(
            for: WidgetSharedStore.subscriptions(asOf: date),
            from: start,
            to: end,
            today: date
        )
        return CalendarEntry(date: date, monthStart: start, markers: markers)
    }

    private func monthStart(from date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct WeekRangeProvider: TimelineProvider {
    let weekCount: Int

    func placeholder(in context: Context) -> WeekRangeEntry {
        WeekRangeEntry(date: .now, startOfWeek: startOfWeek(from: .now), weekCount: weekCount, markers: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekRangeEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekRangeEntry>) -> Void) {
        let entries = WidgetSharedStore.dailyEntryDates().map(makeEntry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date) -> WeekRangeEntry {
        let calendar = Calendar.current
        let start = startOfWeek(from: date)
        let end = calendar.date(byAdding: .day, value: (weekCount * 7) - 1, to: start) ?? start
        let markers = WidgetSharedStore.markers(
            for: WidgetSharedStore.subscriptions(asOf: date),
            from: start,
            to: end,
            today: date
        )
        return WeekRangeEntry(date: date, startOfWeek: start, weekCount: weekCount, markers: markers)
    }

    private func startOfWeek(from date: Date) -> Date {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return calendar.startOfDay(for: interval.start)
        }
        return calendar.startOfDay(for: date)
    }
}

private func koreanWeekdaySymbols(firstWeekday: Int) -> [String] {
    let base = ["일", "월", "화", "수", "목", "금", "토"]
    let shift = max(0, min(6, firstWeekday - 1))
    if shift == 0 { return base }
    return Array(base[shift...]) + Array(base[..<shift])
}

// 앱 결제 캘린더의 요일 헤더와 같은 스타일
private struct WidgetWeekdayHeader: View {
    let font: Font

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(koreanWeekdaySymbols(firstWeekday: Calendar.current.firstWeekday).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(font.weight(.semibold))
                    .foregroundStyle(Color.payMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// 앱 결제 캘린더의 날짜 셀과 같은 스타일. 위젯에서는 오늘이 곧 선택된 날짜다
private struct WidgetCalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isInDisplayedMonth: Bool
    let marker: PaymentCalendarMarker?
    let circleSize: CGFloat
    let font: Font

    private var textColor: Color {
        if isToday {
            return .payAccent
        }
        if !isInDisplayedMonth {
            return Color.payMuted.opacity(0.55)
        }
        return .primary
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(font.weight(isToday ? .bold : .regular))
                .foregroundStyle(textColor)
                .frame(width: circleSize, height: circleSize)
                .background(
                    Circle()
                        .fill(isToday ? Color.payAccent.opacity(0.22) : Color.clear)
                )
            Circle()
                .fill(marker?.dotColor ?? Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CalendarWidgetView: View {
    let entry: CalendarEntry

    // 앱처럼 앞뒤 달 날짜로 첫 주와 마지막 주를 채운다
    private var weeks: [[Date]] {
        let calendar = Calendar.current
        guard let daysRange = calendar.range(of: .day, in: .month, for: entry.monthStart) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: entry.monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let total = leading + daysRange.count
        let cellCount = total + (7 - total % 7) % 7
        let days = (0..<cellCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leading, to: entry.monthStart)
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private var monthTitle: String {
        entry.monthStart.formatted(.dateTime.year().month(.abbreviated).locale(Locale(identifier: "ko_KR")))
    }

    var body: some View {
        let calendar = Calendar.current
        VStack(spacing: PayBoardSpacing.sm) {
            Text(monthTitle)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PayBoardSpacing.xs)

            WidgetWeekdayHeader(font: .caption)
                .padding(.top, PayBoardSpacing.xs)

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        WidgetCalendarDayCell(
                            date: day,
                            isToday: calendar.isDate(day, inSameDayAs: entry.date),
                            isInDisplayedMonth: calendar.isDate(day, equalTo: entry.monthStart, toGranularity: .month),
                            marker: entry.markers[calendar.startOfDay(for: day)],
                            circleSize: 30,
                            font: .subheadline
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(Color.payCard, for: .widget)
    }
}

private struct WeekRangeCalendarWidgetView: View {
    let entry: WeekRangeEntry

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let days = (0..<(entry.weekCount * 7)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: entry.startOfWeek)
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    var body: some View {
        let calendar = Calendar.current
        VStack(spacing: entry.weekCount > 2 ? 2 : PayBoardSpacing.xs) {
            WidgetWeekdayHeader(font: .caption2)

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        WidgetCalendarDayCell(
                            date: day,
                            isToday: calendar.isDate(day, inSameDayAs: entry.date),
                            isInDisplayedMonth: true,
                            marker: entry.markers[calendar.startOfDay(for: day)],
                            circleSize: entry.weekCount > 2 ? 22 : 26,
                            font: .caption
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(Color.payCard, for: .widget)
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

private extension Date {
    // 위젯 번들에 한국어 리소스가 없어 기기 언어와 무관하게 영어로 표시되던 것을 고정
    var koreanDateText: String {
        formatted(.dateTime.year().month().day().locale(Locale(identifier: "ko_KR")))
    }
}
