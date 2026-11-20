import XCTest
@testable import KakeiNote

final class MonthStatisticsTests: XCTestCase {
    private func expense(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        amount: Int,
        category: ExpenseCategory
    ) -> Expense {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        let date = KakeiCalendar.calendar.date(from: components)!
        return Expense(date: date, title: "item", amount: amount, category: category)
    }

    func testMonthlyTotalsAndDailyTotals() {
        let november = KakeiCalendar.date(year: 2026, month: 11, day: 1)!
        let expenses = [
            expense(2026, 11, 1, hour: 9, amount: 500, category: .food),
            expense(2026, 11, 1, hour: 19, amount: 300, category: .dailyGoods),
            expense(2026, 11, 2, amount: 1000, category: .transport),
            expense(2026, 10, 31, amount: 9999, category: .other),
            expense(2026, 12, 1, amount: 8888, category: .other)
        ]

        let statistics = MonthStatistics(expenses: expenses, month: november)

        XCTAssertEqual(statistics.total, 1800)
        XCTAssertEqual(statistics.count, 3)
        XCTAssertEqual(statistics.dailyTotals.count, 2)
        XCTAssertEqual(statistics.total(on: KakeiCalendar.date(year: 2026, month: 11, day: 1)!), 800)
        XCTAssertEqual(statistics.total(on: KakeiCalendar.date(year: 2026, month: 11, day: 2)!), 1000)
        XCTAssertEqual(statistics.categoryTotals[.food], 500)
        XCTAssertEqual(statistics.categoryTotals[.dailyGoods], 300)
        XCTAssertEqual(statistics.categoryTotals[.transport], 1000)
        XCTAssertNil(statistics.categoryTotals[.other])

        let sorted = statistics.sortedCategoryTotals
        XCTAssertEqual(sorted.first?.category, .transport)
        XCTAssertEqual(sorted.first?.amount, 1000)
    }

    func testMonthBoundariesAcrossYears() {
        let december = KakeiCalendar.date(year: 2026, month: 12, day: 15)!
        let january = KakeiCalendar.month(byAdding: 1, to: december)

        let components = KakeiCalendar.calendar.dateComponents([.year, .month], from: january)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 1)

        let previous = KakeiCalendar.month(byAdding: -1, to: KakeiCalendar.startOfMonth(december))
        let previousComponents = KakeiCalendar.calendar.dateComponents([.year, .month], from: previous)
        XCTAssertEqual(previousComponents.year, 2026)
        XCTAssertEqual(previousComponents.month, 11)
    }

    func testMonthGridForNovember2026() {
        let november = KakeiCalendar.date(year: 2026, month: 11, day: 15)!
        let grid = KakeiCalendar.monthGrid(for: november)

        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(grid.compactMap { $0 }.count, 30)
        XCTAssertEqual(KakeiCalendar.leadingWeekdayCount(of: november), 0)
        XCTAssertEqual(KakeiCalendar.calendar.component(.day, from: grid.first!!), 1)
    }

    func testMonthGridForDecember2026() {
        let december = KakeiCalendar.date(year: 2026, month: 12, day: 1)!
        let grid = KakeiCalendar.monthGrid(for: december)

        XCTAssertEqual(KakeiCalendar.leadingWeekdayCount(of: december), 2)
        XCTAssertEqual(grid.count, 35)
        XCTAssertNil(grid[0])
        XCTAssertNil(grid[1])
        XCTAssertEqual(KakeiCalendar.calendar.component(.day, from: grid[2]!), 1)
    }

    func testLeapYearFebruary() {
        let february = KakeiCalendar.date(year: 2028, month: 2, day: 1)!
        XCTAssertEqual(KakeiCalendar.daysInMonth(of: february), 29)
        XCTAssertEqual(KakeiCalendar.monthGrid(for: february).compactMap { $0 }.count, 29)

        let february2026 = KakeiCalendar.date(year: 2026, month: 2, day: 1)!
        XCTAssertEqual(KakeiCalendar.daysInMonth(of: february2026), 28)
    }

    func testEmptyMonthStatistics() {
        let statistics = MonthStatistics(expenses: [], month: Date())
        XCTAssertEqual(statistics.total, 0)
        XCTAssertEqual(statistics.count, 0)
        XCTAssertTrue(statistics.dailyTotals.isEmpty)
        XCTAssertTrue(statistics.categoryTotals.isEmpty)
    }

    func testSameDayComparisonIgnoresTime() {
        let morning = KakeiCalendar.calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let night = KakeiCalendar.calendar.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!
        XCTAssertTrue(KakeiCalendar.isSameDay(morning, night))
    }
}
