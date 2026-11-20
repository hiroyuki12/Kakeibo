import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var model: AppModel

    @State private var month: Date = KakeiCalendar.startOfMonth(Date())
    @State private var selectedDay: Date = KakeiCalendar.startOfDay(Date())
    @State private var editingExpense: Expense?
    @State private var showAddSheet = false
    @State private var expenseToDelete: Expense?

    private var statistics: MonthStatistics {
        model.statistics(for: month)
    }

    private var dayExpenses: [Expense] {
        model.expenses(on: selectedDay)
    }

    private var dayTotal: Int {
        dayExpenses.reduce(0) { $0 + $1.amount }
    }

    private var isCurrentMonth: Bool {
        KakeiCalendar.isSameMonth(month, Date())
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    monthCard
                    calendarCard
                    daySection
                    privacyFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                // iOS 26 のフローティングタブバーに内容が隠れないよう余白を確保
                .padding(.bottom, 96)
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditorView(expense: expense, defaultDate: expense.date)
        }
        .sheet(isPresented: $showAddSheet) {
            ExpenseEditorView(expense: nil, defaultDate: selectedDay)
        }
        .alert("この支出を削除しますか？", isPresented: deleteBinding) {
            Button("削除", role: .destructive) {
                if let expenseToDelete {
                    model.deleteExpense(expenseToDelete)
                    Haptics.success()
                }
                expenseToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                expenseToDelete = nil
            }
        } message: {
            Text(expenseToDelete.map { "\($0.title)（\(JPYFormat.yen($0.amount))）を削除します。" } ?? "")
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CALENDAR")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.4)
                    .foregroundStyle(Theme.accent)
                Text("カレンダー")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    month = KakeiCalendar.startOfMonth(Date())
                    selectedDay = KakeiCalendar.startOfDay(Date())
                }
                Haptics.selection()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .bold))
                    Text("今日")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.accentSoft))
                .overlay(Capsule().stroke(Theme.accent.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("calendar.todayButton")
        }
        .padding(.top, 4)
    }

    // MARK: - 月間合計

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                monthArrow(systemName: "chevron.left", offset: -1, label: "前月")

                Spacer()

                VStack(spacing: 3) {
                    Text(DateLabels.monthTitle(month))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(statistics.count)件の支出")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                monthArrow(systemName: "chevron.right", offset: 1, label: "翌月")
            }

            VStack(spacing: 5) {
                Text(isCurrentMonth ? "今月の支出" : "この月の支出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Text(JPYFormat.yen(statistics.total))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .accessibilityIdentifier("calendar.monthTotal")
            }
            .padding(.vertical, 2)

            categoryBreakdown
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.surface, Theme.backgroundElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -50 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 50 {
                        changeMonth(by: -1)
                    }
                }
        )
    }

    private func monthArrow(systemName: String, offset: Int, label: String) -> some View {
        Button {
            changeMonth(by: offset)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var categoryBreakdown: some View {
        let entries = Array(statistics.sortedCategoryTotals.prefix(6))
        if !entries.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(entries, id: \.category) { entry in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(entry.category.tint)
                                .frame(width: 6, height: 6)
                            Text(entry.category.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                            Text(JPYFormat.compact(entry.amount))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.surfaceHigh))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - カレンダー

    private var calendarCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(DateLabels.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(weekdayColor(index))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(Array(KakeiCalendar.monthGrid(for: month).enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDayCell(
                            date: day,
                            total: statistics.total(on: day),
                            isSelected: KakeiCalendar.isSameDay(day, selectedDay),
                            isToday: KakeiCalendar.isToday(day)
                        ) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                selectedDay = day
                            }
                            Haptics.selection()
                        }
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return Theme.sunday }
        if index == 6 { return Theme.saturday }
        return Theme.textSecondary
    }

    // MARK: - 選択日の支出一覧

    private var daySection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(DateLabels.dayTitle(selectedDay))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    if dayExpenses.isEmpty {
                        Text("この日の支出はありません")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Text("\(dayExpenses.count)件 · 合計 \(JPYFormat.yen(dayTotal))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Button {
                    showAddSheet = true
                    Haptics.selection()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("追加")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("calendar.addButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 8)

            if dayExpenses.isEmpty {
                EmptyStateView(
                    symbol: "tray",
                    title: "支出が登録されていません",
                    message: "「追加」からこの日の支出を登録できます"
                )
                .padding(.bottom, 8)
            } else {
                ForEach(Array(dayExpenses.enumerated()), id: \.element.id) { index, expense in
                    HStack(spacing: 2) {
                        Button {
                            editingExpense = expense
                        } label: {
                            ExpenseRowContent(expense: expense)
                        }
                        .buttonStyle(PressableButtonStyle())

                        Menu {
                            Button {
                                editingExpense = expense
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                expenseToDelete = expense
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 30, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)

                    if index < dayExpenses.count - 1 {
                        ExpenseDivider()
                            .padding(.trailing, 16)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .surfaceCard(padding: 0)
    }

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("支出データはこの端末の中だけに保存されます")
                .font(.system(size: 10))
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 操作

    private func changeMonth(by offset: Int) {
        let next = KakeiCalendar.month(byAdding: offset, to: month)
        withAnimation(.easeInOut(duration: 0.22)) {
            month = next
            if KakeiCalendar.isSameMonth(next, Date()) {
                selectedDay = KakeiCalendar.startOfDay(Date())
            } else {
                selectedDay = next
            }
        }
        Haptics.selection()
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { expenseToDelete != nil },
            set: { newValue in
                if !newValue { expenseToDelete = nil }
            }
        )
    }
}

// MARK: - 日付セル

private struct CalendarDayCell: View {
    let date: Date
    let total: Int
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        String(KakeiCalendar.calendar.component(.day, from: date))
    }

    private var weekday: Int {
        DateLabels.weekdayIndex(of: date)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return Theme.accent }
        if weekday == 0 { return Theme.sunday.opacity(0.9) }
        if weekday == 6 { return Theme.saturday.opacity(0.9) }
        return Theme.textPrimary
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(dayNumber)
                    .font(.system(size: 14, weight: isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(textColor)

                if total > 0 {
                    Text(JPYFormat.compact(total))
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .padding(.horizontal, 1)
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.accent : (isToday ? Theme.accentSoft : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday && !isSelected ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DateLabels.dayTitle(date))、支出 \(total > 0 ? JPYFormat.yen(total) : "なし")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
