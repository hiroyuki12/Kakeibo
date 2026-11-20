import Foundation

/// 日付の境界や月計算を一箇所にまとめる。保存時は常に「その日の 0:00」に正規化する。
enum KakeiCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .current
        calendar.firstWeekday = 1 // 日曜始まり
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? startOfDay(date)
    }

    static func month(byAdding value: Int, to date: Date) -> Date {
        let base = startOfMonth(date)
        return calendar.date(byAdding: .month, value: value, to: base) ?? base
    }

    static func daysInMonth(of date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// 月初の曜日を日曜=0 としたインデックスで返す。
    static func leadingWeekdayCount(of month: Date) -> Int {
        calendar.component(.weekday, from: startOfMonth(month)) - 1
    }

    /// 月間カレンダー用のマス。月初前の空白は nil。
    static func monthGrid(for month: Date) -> [Date?] {
        let base = startOfMonth(month)
        let leading = leadingWeekdayCount(of: month)
        let days = daysInMonth(of: month)
        let cellCount = Int(ceil(Double(leading + days) / 7.0)) * 7
        return (0..<cellCount).map { index in
            let dayOffset = index - leading
            guard dayOffset >= 0, dayOffset < days else { return nil }
            return calendar.date(byAdding: .day, value: dayOffset, to: base)
        }
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func date(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        return startOfDay(date)
    }

    /// 指定した日付の月の全日を返す。
    static func days(of month: Date) -> [Date] {
        let base = startOfMonth(month)
        return (0..<daysInMonth(of: month)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: base)
        }
    }
}

/// 月間・日別の集計。値型なのでテストしやすい。
struct MonthStatistics {
    let month: Date
    let total: Int
    let dailyTotals: [Date: Int]
    let categoryTotals: [ExpenseCategory: Int]
    let count: Int

    init(expenses: [Expense], month: Date) {
        let targetMonth = KakeiCalendar.startOfMonth(month)
        let filtered = expenses.filter { KakeiCalendar.isSameMonth($0.date, targetMonth) }

        var daily: [Date: Int] = [:]
        var categories: [ExpenseCategory: Int] = [:]
        var total = 0

        for expense in filtered {
            let day = KakeiCalendar.startOfDay(expense.date)
            daily[day, default: 0] += expense.amount
            categories[expense.category, default: 0] += expense.amount
            total += expense.amount
        }

        self.month = targetMonth
        self.total = total
        self.dailyTotals = daily
        self.categoryTotals = categories
        self.count = filtered.count
    }

    func total(on day: Date) -> Int {
        dailyTotals[KakeiCalendar.startOfDay(day)] ?? 0
    }

    /// 金額の大きい順のカテゴリ内訳。
    var sortedCategoryTotals: [(category: ExpenseCategory, amount: Int)] {
        categoryTotals
            .map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
