import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: MemoStore
    @AppStorage("statisticsStreakIconAnimationDay") private var lastStreakIconAnimationDay = ""
    @Binding var isTabBarHidden: Bool
    @Namespace private var categoryTransitionNamespace

    private let statisticsEntryID: UUID

    @State private var selectedMonth: Date
    @State private var selectedDate: Date
    @State private var selectedWeekDate: Date
    @State private var navigationPath: [MemoCategory] = []
    @State private var calendarDragOffset: CGFloat = 0
    @State private var isCompletingMonthSwipe = false
    @State private var displayedStreakIconAsset = "StatsStreak0"
    @State private var streakIconScale: CGFloat = 1
    @State private var animatedStreakEntryID: UUID?
    @State private var streakIconAnimationID = UUID()

    private let calendar: Calendar
    private let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    private let trendColors: [Color] = [
        Theme.Colors.accent,
        Theme.Colors.cream,
        Theme.Colors.mint,
        Theme.Colors.sky,
        Theme.Colors.lavender,
        Theme.Colors.pink,
        Theme.Colors.cream
    ]

    init(isTabBarHidden: Binding<Bool>, entryID: UUID) {
        _isTabBarHidden = isTabBarHidden
        statisticsEntryID = entryID

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        self.calendar = calendar

        let today = Date()
        _selectedMonth = State(initialValue: calendar.dateInterval(of: .month, for: today)?.start ?? today)
        _selectedDate = State(initialValue: today)
        _selectedWeekDate = State(initialValue: today)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 6) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        calendarCard
                        metricGrid
                        weeklyTrendCard
                        categoryStatisticsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 132)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MemoCategory.self) { category in
                categoryDestination(category)
            }
        }
        .onChange(of: navigationPath) { _, path in
            isTabBarHidden = !path.isEmpty
        }
        .onChange(of: statisticsEntryID) {
            playStreakEntryAnimationIfNeeded()
        }
        .onAppear {
            playStreakEntryAnimationIfNeeded()
        }
        .onDisappear {
            isTabBarHidden = false
        }
    }

    @ViewBuilder
    private func categoryDestination(_ category: MemoCategory) -> some View {
        let detail = StatisticsCategoryDetailView(
            category: category,
            month: selectedMonth,
            calendar: calendar
        )
        .background(Theme.Colors.background.ignoresSafeArea())
        .windowBackground(UIColor(Theme.Colors.background))
        .disablesNavigationDragDismiss()

        if #available(iOS 18.0, *) {
            detail
                .navigationTransition(.zoom(sourceID: category.id, in: categoryTransitionNamespace))
        } else {
            detail
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("EditorStickerCalendar")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text("日历统计")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Theme.Colors.text)

                Text("看看这个月的小记录吧 ✨")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.muted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthSwitcher: some View {
        HStack(spacing: 12) {
            monthButton(systemName: "chevron.left") {
                moveMonth(by: -1)
            }

            Spacer(minLength: 0)

            Text(monthTitle)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Theme.Colors.text)

            Spacer(minLength: 0)

            monthButton(systemName: "chevron.right") {
                moveMonth(by: 1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.82))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 7, y: 3)
        }
        .buttonStyle(StatisticsPressStyle())
    }

    private var calendarCard: some View {
        VStack(spacing: 10) {
            monthSwitcher

            LazyVGrid(columns: calendarColumns, spacing: 0) {
                ForEach(Array(weekdayTitles.enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(index >= 5 ? Theme.Colors.accentStrong : Theme.Colors.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                }
            }

            Divider()
                .overlay(Theme.Colors.line.opacity(0.7))

            calendarMonthPages
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .statisticsCard()
    }

    private var calendarMonthPages: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                calendarMonthGrid(for: month(byAdding: -1), pageWidth: geometry.size.width, isInteractive: false)
                calendarMonthGrid(for: selectedMonth, pageWidth: geometry.size.width, isInteractive: true)
                calendarMonthGrid(for: month(byAdding: 1), pageWidth: geometry.size.width, isInteractive: false)
            }
            .offset(x: -geometry.size.width + calendarDragOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(calendarSwipeGesture(pageWidth: geometry.size.width))
        }
        .frame(height: monthGridHeight(for: selectedMonth))
        .clipped()
    }

    private func calendarMonthGrid(for month: Date, pageWidth: CGFloat, isInteractive: Bool) -> some View {
        LazyVGrid(columns: calendarColumns, spacing: 4) {
            ForEach(monthGrid(for: month)) { item in
                if let date = item.date {
                    calendarDayCell(date)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .frame(width: pageWidth)
        .opacity(isInteractive ? 1 : monthSwipeProgress)
        .allowsHitTesting(isInteractive && !isCompletingMonthSwipe)
    }

    private func calendarDayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let memos = memos(on: date)
        let markerCategory = memos.first?.category

        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                selectedDate = date
                selectedWeekDate = date
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Theme.Colors.pink.opacity(0.72))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: Theme.Colors.accent.opacity(0.18), radius: 6, y: 2)
                } else if !memos.isEmpty {
                    Circle()
                        .fill((markerCategory?.tint ?? Theme.Colors.cream).opacity(0.62))
                }

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 15, weight: isSelected || isToday ? .black : .bold))
                        .foregroundStyle(dayTextColor(for: date, isSelected: isSelected))

                    Circle()
                        .fill(memos.isEmpty ? .clear : (markerCategory?.tint ?? Theme.Colors.accent))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: 40, height: 40)
            .overlay {
                if isToday && !isSelected {
                    Circle()
                        .stroke(Theme.Colors.accentStrong, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .accessibilityLabel(dayAccessibilityLabel(date: date, memoCount: memos.count))
    }

    private var metricGrid: some View {
        HStack(spacing: 6) {
            metricCard(title: "本月记录", value: "\(monthlyRecordDays) 天", iconAsset: "StatsMonthlyRecord", tint: Theme.Colors.pink)
            metricCard(title: "连续记录", value: "\(recordingStreak) 天", iconAsset: displayedStreakIconAsset, tint: Theme.Colors.cream, iconScale: streakIconScale)
            metricCard(title: "完成待办", value: "\(completedTodoCount) 项", iconAsset: "StatsCompletedTodo", tint: Theme.Colors.sky)
        }
        .padding(10)
        .statisticsCard()
    }

    private func metricCard(title: String, value: String, iconAsset: String, tint: Color, iconScale: CGFloat = 1) -> some View {
        HStack(spacing: 8) {
            Image(iconAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .scaleEffect(iconScale)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(value)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white, lineWidth: 1)
        )
    }

    private var weeklyTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                statisticsSectionTitle("本周趋势", systemName: "chart.bar.fill")

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    weekNavigationButton(
                        systemName: "chevron.left",
                        label: "上一周",
                        offset: -1,
                        isDisabled: !canMoveToPreviousWeek
                    )

                    Text(weekPositionTitle)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(minWidth: 48)

                    weekNavigationButton(
                        systemName: "chevron.right",
                        label: "下一周",
                        offset: 1,
                        isDisabled: !canMoveToNextWeek
                    )
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(weeklyCounts.enumerated()), id: \.offset) { index, count in
                    VStack(spacing: 5) {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Theme.Colors.text)

                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(trendColors[index].opacity(0.78))
                            .frame(height: trendBarHeight(for: count))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(.white, lineWidth: 1)
                            )

                        Text("周\(weekdayTitles[index])")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 132, alignment: .bottom)
            .animation(.easeOut(duration: 0.20), value: selectedWeekDate)
        }
        .padding(16)
        .statisticsCard()
    }

    private func weekNavigationButton(
        systemName: String,
        label: String,
        offset: Int,
        isDisabled: Bool
    ) -> some View {
        Button {
            moveWeek(by: offset)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.82))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .shadow(color: Theme.Colors.shadow.opacity(0.09), radius: 5, y: 2)
        }
        .buttonStyle(StatisticsPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private var categoryStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            statisticsSectionTitle("分类统计", systemName: "square.grid.2x2.fill")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(MemoCategory.allCases) { category in
                    categoryRow(category)
                }
            }
        }
        .padding(16)
        .statisticsCard()
    }

    private func categoryRow(_ category: MemoCategory) -> some View {
        let count = monthMemos.filter { $0.category == category }.count
        let maximum = max(1, categoryMaximumCount)

        return NavigationLink(value: category) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(category.iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)

                    Text(category.title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.Colors.text)

                    Spacer(minLength: 0)

                    Text("\(count) 条")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.muted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.Colors.muted.opacity(0.78))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.line.opacity(0.48))

                        Capsule()
                            .fill(category.tint)
                            .frame(width: geometry.size.width * CGFloat(count) / CGFloat(maximum))
                    }
                }
                .frame(height: 7)
            }
            .padding(12)
            .frame(minHeight: 76)
            .background(category.tint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white, lineWidth: 1)
            )
            .statisticsCategoryTransitionSource(for: category.id, in: categoryTransitionNamespace)
        }
        .buttonStyle(StatisticsPressStyle())
        .accessibilityLabel("\(monthTitle)，\(category.title)，\(count)条便签")
    }

    private func statisticsSectionTitle(_ title: String, systemName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.Colors.accentStrong)

            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.Colors.text)
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    }

    private var monthInterval: DateInterval {
        monthInterval(for: selectedMonth)
    }

    private var monthMemos: [Memo] {
        store.memos.filter { monthInterval.contains($0.createdAt) }
    }

    private var monthTitle: String {
        monthTitle(for: selectedMonth)
    }

    private func monthTitle(for month: Date) -> String {
        "\(calendar.component(.year, from: month)) 年 \(calendar.component(.month, from: month)) 月"
    }

    private func monthGrid(for month: Date) -> [StatisticsCalendarDay] {
        guard let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let interval = monthInterval(for: month)
        let weekday = calendar.component(.weekday, from: interval.start)
        let leadingBlankCount = (weekday - calendar.firstWeekday + 7) % 7

        var result = (0..<leadingBlankCount).map { StatisticsCalendarDay(id: $0, date: nil) }
        for day in days {
            let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start)
            result.append(StatisticsCalendarDay(id: result.count, date: date))
        }
        return result
    }

    private func monthGridHeight(for month: Date) -> CGFloat {
        let rowCount = max(1, Int(ceil(Double(monthGrid(for: month).count) / 7.0)))
        return CGFloat(rowCount * 44 + max(0, rowCount - 1) * 4)
    }

    private func monthInterval(for month: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, duration: 31 * 24 * 60 * 60)
    }

    private var monthlyRecordDays: Int {
        Set(monthMemos.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private var completedTodoCount: Int {
        monthMemos
            .flatMap(\.todoItems)
            .filter(\.isCompleted)
            .count
    }

    private var recordingStreak: Int {
        let recordedDays = Set(store.memos.map { calendar.startOfDay(for: $0.createdAt) })
        var cursor = calendar.startOfDay(for: Date())

        if !recordedDays.contains(cursor), let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }

        var streak = 0
        while recordedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private var streakIconAsset: String {
        switch recordingStreak {
        case 0:
            return "StatsStreak0"
        case 1..<7:
            return "StatsStreak1"
        case 7..<12:
            return "StatsStreak2"
        case 12..<15:
            return "StatsStreak3"
        default:
            return "StatsStreak4"
        }
    }

    private var streakAnimationDayKey: String {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func playStreakEntryAnimationIfNeeded() {
        let targetIconAsset = streakIconAsset
        guard animatedStreakEntryID != statisticsEntryID else {
            displayedStreakIconAsset = targetIconAsset
            streakIconScale = 1
            return
        }

        animatedStreakEntryID = statisticsEntryID
        streakIconAnimationID = UUID()
        let animationID = streakIconAnimationID

        guard targetIconAsset != "StatsStreak0" else {
            displayedStreakIconAsset = "StatsStreak0"
            streakIconScale = 1
            return
        }

        guard lastStreakIconAnimationDay != streakAnimationDayKey else {
            displayedStreakIconAsset = targetIconAsset
            streakIconScale = 1
            return
        }

        lastStreakIconAnimationDay = streakAnimationDayKey

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedStreakIconAsset = "StatsStreak0"
            streakIconScale = 1
        }

        DispatchQueue.main.async {
            guard streakIconAnimationID == animationID else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                streakIconScale = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            guard streakIconAnimationID == animationID else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedStreakIconAsset = targetIconAsset
                streakIconScale = 0
            }

            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                streakIconScale = 1
            }
        }
    }

    private var weekDates: [Date] {
        let monday = startOfWeek(containing: selectedWeekDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var monthWeekStarts: [Date] {
        let starts = monthGrid(for: selectedMonth)
            .compactMap(\.date)
            .map(startOfWeek(containing:))
        return Array(Set(starts)).sorted()
    }

    private var selectedWeekIndex: Int {
        let selectedWeekStart = startOfWeek(containing: selectedWeekDate)
        return monthWeekStarts.firstIndex { calendar.isDate($0, inSameDayAs: selectedWeekStart) } ?? 0
    }

    private var weekPositionTitle: String {
        "第 \(selectedWeekIndex + 1) 周"
    }

    private var canMoveToPreviousWeek: Bool {
        selectedWeekIndex > 0
    }

    private var canMoveToNextWeek: Bool {
        selectedWeekIndex < monthWeekStarts.count - 1
    }

    private var weeklyCounts: [Int] {
        weekDates.map { date in
            store.memos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
        }
    }

    private func moveWeek(by value: Int) {
        let targetIndex = selectedWeekIndex + value
        guard monthWeekStarts.indices.contains(targetIndex) else { return }
        selectedWeekDate = monthWeekStarts[targetIndex]
    }

    private func startOfWeek(containing date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(
            byAdding: .day,
            value: -daysFromMonday,
            to: calendar.startOfDay(for: date)
        ) ?? calendar.startOfDay(for: date)
    }

    private var categoryMaximumCount: Int {
        MemoCategory.allCases
            .map { category in monthMemos.filter { $0.category == category }.count }
            .max() ?? 1
    }

    private func trendBarHeight(for count: Int) -> CGFloat {
        let maximum = max(1, weeklyCounts.max() ?? 1)
        return max(8, 76 * CGFloat(count) / CGFloat(maximum))
    }

    private func memos(on date: Date) -> [Memo] {
        store.memos.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    private func dayTextColor(for date: Date, isSelected: Bool) -> Color {
        if isSelected {
            return Theme.Colors.text
        }
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 ? Theme.Colors.accentStrong : Theme.Colors.text.opacity(0.84)
    }

    private func dayAccessibilityLabel(date: Date, memoCount: Int) -> String {
        let day = calendar.component(.day, from: date)
        return memoCount == 0 ? "\(day)日，无记录" : "\(day)日，\(memoCount)条记录"
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) else { return }
        let start = calendar.dateInterval(of: .month, for: nextMonth)?.start ?? nextMonth
        withAnimation(.easeOut(duration: 0.20)) {
            selectedMonth = start
            let date = calendar.isDate(start, equalTo: Date(), toGranularity: .month) ? Date() : start
            selectedDate = date
            selectedWeekDate = date
        }
    }

    private var monthSwipeProgress: CGFloat {
        min(abs(calendarDragOffset) / 240, 1)
    }

    private func month(byAdding value: Int) -> Date {
        guard let date = calendar.date(byAdding: .month, value: value, to: selectedMonth) else {
            return selectedMonth
        }
        return calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func calendarSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isCompletingMonthSwipe else { return }

                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                guard abs(horizontalDistance) > abs(verticalDistance) * 1.15 else {
                    calendarDragOffset = 0
                    return
                }

                calendarDragOffset = min(max(horizontalDistance, -pageWidth), pageWidth)
            }
            .onEnded { value in
                finishMonthSwipe(value, pageWidth: pageWidth)
            }
    }

    private func finishMonthSwipe(_ value: DragGesture.Value, pageWidth: CGFloat) {
        guard !isCompletingMonthSwipe else { return }

        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        let predictedDistance = value.predictedEndTranslation.width
        let isHorizontal = abs(horizontalDistance) > abs(verticalDistance) * 1.15
        let shouldChangeMonth = isHorizontal && (
            abs(horizontalDistance) >= pageWidth * 0.22
                || abs(predictedDistance) >= pageWidth * 0.42
        )

        guard shouldChangeMonth else {
            withAnimation(.easeOut(duration: 0.20)) {
                calendarDragOffset = 0
            }
            return
        }

        let monthDelta = horizontalDistance < 0 ? 1 : -1
        let targetMonth = month(byAdding: monthDelta)
        isCompletingMonthSwipe = true

        withAnimation(.easeOut(duration: 0.24)) {
            calendarDragOffset = monthDelta > 0 ? -pageWidth : pageWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedMonth = targetMonth
                selectedDate = calendar.isDate(targetMonth, equalTo: Date(), toGranularity: .month)
                    ? Date()
                    : targetMonth
                selectedWeekDate = selectedDate
                calendarDragOffset = 0
                isCompletingMonthSwipe = false
            }
        }
    }
}

private struct StatisticsCategoryDetailView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @Namespace private var memoTransitionNamespace

    let category: MemoCategory
    let month: Date
    let calendar: Calendar

    private var categoryMemos: [Memo] {
        store.memos
            .filter { memo in
                memo.category == category && monthInterval.contains(memo.createdAt)
            }
            .sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, duration: 31 * 24 * 60 * 60)
    }

    private var monthTitle: String {
        "\(calendar.component(.year, from: month)) 年 \(calendar.component(.month, from: month)) 月"
    }

    var body: some View {
        VStack(spacing: 6) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 12) {
                    if categoryMemos.isEmpty {
                        emptyState
                    } else {
                        ForEach(categoryMemos) { memo in
                            NavigationLink {
                                memoDestination(memo)
                            } label: {
                                StatisticsMemoListCard(memo: memo)
                                    .statisticsMemoTransitionSource(for: memo.id, in: memoTransitionNamespace)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 132)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("\(category.title)便签")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(Theme.Colors.text)

                Text("\(monthTitle) · \(categoryMemos.count) 条")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.muted)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 7, y: 3)
                }
                .buttonStyle(StatisticsPressStyle())
                .accessibilityLabel("返回统计")

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("EmptyMemoState")
                .resizable()
                .scaledToFit()
                .frame(width: 154, height: 154)
                .accessibilityLabel("暂无便签")

            Text("暂无\(category.title)便签")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.Colors.text)

            Text("这个月还没有对「\(category.title)」便签记录")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .statisticsCard()
    }

    @ViewBuilder
    private func memoDestination(_ memo: Memo) -> some View {
        let detail = StatisticsMemoReadOnlyDetailView(memo: memo)
            .background(Theme.Colors.background.ignoresSafeArea())
            .windowBackground(UIColor(Theme.Colors.background))
            .disablesNavigationDragDismiss()

        if #available(iOS 18.0, *) {
            detail
                .navigationTransition(.zoom(sourceID: memo.id, in: memoTransitionNamespace))
        } else {
            detail
        }
    }
}

private struct StatisticsMemoListCard: View {
    let memo: Memo

    private var dateText: String {
        memo.createdAt.formatted(
            .dateTime
                .locale(Locale(identifier: "zh_CN"))
                .month()
                .day()
                .hour()
                .minute()
        )
    }

    private var contentPreview: String {
        let trimmedContent = memo.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty {
            return trimmedContent
        }

        let todoPreview = memo.todoItems
            .map { item in item.isCompleted ? "已完成 \(item.text)" : item.text }
            .joined(separator: "、")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return todoPreview.isEmpty ? "暂无正文内容" : todoPreview
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(memo.category.iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text(memo.category.title)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.Colors.text)

                    Spacer(minLength: 0)
                }

                Text(memo.title)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                Text(contentPreview)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Colors.text.opacity(0.78))
                    .lineLimit(3)
                    .lineSpacing(4)
                    .frame(maxWidth: 250, alignment: .leading)

                Text(dateText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.muted)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .padding(.trailing, 64)

            Image(memo.category.stickerAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .opacity(0.92)
                .padding(.trailing, 14)
        }
        .background(Theme.Colors.memoCard)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white, lineWidth: 2)
        )
        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

private struct StatisticsMemoReadOnlyDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let memo: Memo

    private var dateText: String {
        memo.createdAt.formatted(
            .dateTime
                .locale(Locale(identifier: "zh_CN"))
                .year()
                .month()
                .day()
                .hour()
                .minute()
        )
    }

    private var contentText: String {
        let trimmedContent = memo.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedContent.isEmpty ? "暂无正文内容" : trimmedContent
    }

    var body: some View {
        VStack(spacing: 6) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                memoContent
                    .padding(.horizontal, 20)
                    .padding(.bottom, 132)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ZStack {
            Text("便签详情")
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(Theme.Colors.text)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.82))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 7, y: 3)
                }
                .buttonStyle(StatisticsPressStyle())
                .accessibilityLabel("返回分类便签")

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var memoContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(memo.category.iconAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                Text(memo.category.title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.Colors.text)

                Spacer(minLength: 0)
            }

            Text(memo.title)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dateText)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.muted)

            Divider()
                .overlay(Theme.Colors.line.opacity(0.7))

            Text(contentText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.Colors.text.opacity(0.82))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !memo.todoItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(memo.todoItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(item.isCompleted ? Theme.Colors.accentStrong : Theme.Colors.muted)
                                .padding(.top, 1)

                            Text(item.text)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Colors.text.opacity(item.isCompleted ? 0.58 : 0.82))
                                .strikethrough(item.isCompleted, color: Theme.Colors.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 18)
    }
}

private struct StatisticsCalendarDay: Identifiable {
    let id: Int
    let date: Date?
}

private struct StatisticsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    @ViewBuilder
    func statisticsCategoryTransitionSource(for id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func statisticsMemoTransitionSource(for id: UUID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    func statisticsCard() -> some View {
        background(Theme.Colors.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white, lineWidth: 2)
            )
            .shadow(color: Theme.Colors.shadow.opacity(0.11), radius: 15, y: 7)
    }
}
