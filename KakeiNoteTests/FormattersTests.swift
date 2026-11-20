import XCTest
@testable import KakeiNote

final class FormattersTests: XCTestCase {
    func testGroupedDigits() {
        XCTAssertEqual(JPYFormat.grouped("0"), "0")
        XCTAssertEqual(JPYFormat.grouped("123"), "123")
        XCTAssertEqual(JPYFormat.grouped("1234"), "1,234")
        XCTAssertEqual(JPYFormat.grouped("1234567"), "1,234,567")
        XCTAssertEqual(JPYFormat.grouped(""), "")
    }

    func testFormattedInput() {
        XCTAssertEqual(JPYFormat.formattedInput(""), "")
        XCTAssertEqual(JPYFormat.formattedInput("0"), "0")
        XCTAssertEqual(JPYFormat.formattedInput("000"), "0")
        XCTAssertEqual(JPYFormat.formattedInput("01280"), "1,280")
        XCTAssertEqual(JPYFormat.formattedInput("１２８０"), "1,280")
        XCTAssertEqual(JPYFormat.formattedInput("¥1,280"), "1,280")
        XCTAssertEqual(JPYFormat.formattedInput("1,2a8b0"), "1,280")
    }

    func testAmountParsing() {
        XCTAssertEqual(JPYFormat.amount(from: "¥1,280"), 1280)
        XCTAssertEqual(JPYFormat.amount(from: "１２８０円"), 1280)
        XCTAssertEqual(JPYFormat.amount(from: "0"), 0)
        XCTAssertEqual(JPYFormat.amount(from: ""), 0)
        XCTAssertEqual(JPYFormat.amount(from: "abc"), 0)
    }

    func testYenFormatting() {
        XCTAssertEqual(JPYFormat.yen(0), "¥0")
        XCTAssertEqual(JPYFormat.yen(1280), "¥1,280")
        XCTAssertEqual(JPYFormat.yen(1234567), "¥1,234,567")
        XCTAssertEqual(JPYFormat.compact(980), "¥980")
        XCTAssertEqual(JPYFormat.compact(12345), "¥12,345")
        XCTAssertEqual(JPYFormat.compact(1_234_567), "¥123.5万")
    }

    func testDateLabels() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 21
        guard let date = KakeiCalendar.calendar.date(from: components) else {
            return XCTFail("日付を作れませんでした")
        }

        XCTAssertEqual(DateLabels.monthTitle(date), "2026年11月")
        XCTAssertEqual(DateLabels.dayTitle(date), "11月21日（土）")
        XCTAssertEqual(DateLabels.fullDayTitle(date), "2026年11月21日（土）")
        XCTAssertEqual(DateLabels.weekdaySymbols.count, 7)
    }

    func testExpenseNormalizesDateToStartOfDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 20
        components.hour = 23
        components.minute = 45
        let date = KakeiCalendar.calendar.date(from: components)!
        let expense = Expense(date: date, title: "テスト", amount: 100, category: .food)
        let hour = KakeiCalendar.calendar.component(.hour, from: expense.date)
        XCTAssertEqual(hour, 0)
        XCTAssertTrue(KakeiCalendar.isSameDay(expense.date, date))
    }
}
