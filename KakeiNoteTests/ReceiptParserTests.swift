import XCTest
@testable import KakeiNote

final class ReceiptParserTests: XCTestCase {
    private let parser = ReceiptParser()

    private var referenceDate: Date {
        KakeiCalendar.date(year: 2026, month: 11, day: 21)!
    }

    func testParsesSupermarketReceipt() {
        let text = """
        イオンスタイル 渋谷店
        〒150-0002 東京都渋谷区渋谷1-2-3
        TEL 03-1234-5678
        2026年11月20日 19:32
        レジ 03 担当 佐藤
        牛乳 1L              ¥198
        たまご 10個           ¥248
        洗剤 詰替 398
        ティッシュ 5箱        328
        --------------------------
        小計                 ¥1,172
        消費税(8%)            ¥93
        合計                 ¥1,265
        お預り              ¥2,000
        お釣り                ¥735
        """

        let result = parser.parse(text, referenceDate: referenceDate)

        XCTAssertEqual(result.merchantName, "イオンスタイル 渋谷店")
        XCTAssertEqual(result.declaredTotal, 1265)
        XCTAssertEqual(result.subtotal, 1172)
        XCTAssertEqual(result.items.count, 4)
        XCTAssertEqual(result.itemsTotal, 1172)
        XCTAssertTrue(result.hasMismatch)
        XCTAssertEqual(result.difference, 93)

        let names = result.items.map(\.name)
        XCTAssertEqual(names, ["牛乳 1L", "たまご", "洗剤 詰替", "ティッシュ"])
        XCTAssertEqual(result.items.map(\.amount), [198, 248, 398, 328])
        XCTAssertEqual(result.items.map(\.category), [.food, .food, .dailyGoods, .dailyGoods])

        let dateComponents = KakeiCalendar.calendar.dateComponents([.year, .month, .day], from: result.date!)
        XCTAssertEqual(dateComponents.year, 2026)
        XCTAssertEqual(dateComponents.month, 11)
        XCTAssertEqual(dateComponents.day, 20)
    }

    func testParsesQuantityNotation() {
        let text = """
        スーパーABC
        2026/11/19
        りんご 3個 @158 = 474
        牛乳 2 x 198 = 396
        食パン 158
        合計 1,028
        """

        let result = parser.parse(text, referenceDate: referenceDate)

        XCTAssertEqual(result.merchantName, "スーパーABC")
        XCTAssertEqual(result.declaredTotal, 1028)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items.map(\.name), ["りんご", "牛乳", "食パン"])
        XCTAssertEqual(result.items.map(\.amount), [474, 396, 158])
        XCTAssertEqual(result.items[0].quantity, 3)
        XCTAssertEqual(result.items[1].quantity, 2)
        XCTAssertEqual(result.items[1].unitPrice, 198)
        XCTAssertFalse(result.hasMismatch)
    }

    func testParsesFullWidthCharacters() {
        let text = """
        牛乳　１２３
        合計　￥１２３
        """

        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.name, "牛乳")
        XCTAssertEqual(result.items.first?.amount, 123)
        XCTAssertEqual(result.declaredTotal, 123)
    }

    func testDateFormats() {
        let slash = parser.parse("2026/11/20\n牛乳 198", referenceDate: referenceDate)
        XCTAssertEqual(slash.date, KakeiCalendar.date(year: 2026, month: 11, day: 20))

        let reiwa = parser.parse("R8.11.20\n牛乳 198", referenceDate: referenceDate)
        XCTAssertEqual(reiwa.date, KakeiCalendar.date(year: 2026, month: 11, day: 20))

        let noYear = parser.parse("11月20日\n牛乳 198", referenceDate: referenceDate)
        XCTAssertEqual(noYear.date, KakeiCalendar.date(year: 2026, month: 11, day: 20))

        let newYearReference = KakeiCalendar.date(year: 2026, month: 1, day: 5)!
        let previousYear = parser.parse("12月31日\n牛乳 198", referenceDate: newYearReference)
        XCTAssertEqual(previousYear.date, KakeiCalendar.date(year: 2025, month: 12, day: 31))

        let invalid = parser.parse("2026年2月30日\n牛乳 198", referenceDate: referenceDate)
        XCTAssertNil(invalid.date)
    }

    func testFallsBackToSingleTotalWhenNoItems() {
        let text = """
        ドトールコーヒー 渋谷店
        2026/11/20
        合計 ¥580
        """

        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.declaredTotal, 580)
        XCTAssertEqual(result.merchantName, "ドトールコーヒー 渋谷店")
        XCTAssertFalse(result.hasMismatch)
    }

    func testUsesSubtotalWhenTotalMissing() {
        let text = """
        スーパー
        牛乳 198
        小計 198
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.declaredTotal, 198)
        XCTAssertEqual(result.subtotal, 198)
    }

    func testDetectsMismatch() {
        let text = """
        スーパー
        牛乳 198
        パン 100
        合計 400
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.itemsTotal, 298)
        XCTAssertEqual(result.declaredTotal, 400)
        XCTAssertTrue(result.hasMismatch)
        XCTAssertEqual(result.difference, 102)
    }

    func testIgnoresPaymentAndTaxLines() {
        let text = """
        A店
        牛乳 198
        合計 198
        お預り 1000
        お釣り 802
        消費税 14
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.amount, 198)
        XCTAssertEqual(result.declaredTotal, 198)
    }

    func testIgnoresBarcodeOnlyLines() {
        let text = """
        4901234567894
        牛乳 198
        合計 198
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.name, "牛乳")
    }

    func testIgnoresStoreHeaderWithDigits() {
        let text = """
        セブン-イレブン 渋谷1丁目店
        おにぎり 158
        合計 158
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.name, "おにぎり")
        XCTAssertEqual(result.items.first?.amount, 158)
    }

    func testEmptyTextReturnsEmptyResult() {
        let result = parser.parse("", referenceDate: referenceDate)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNil(result.declaredTotal)
        XCTAssertNil(result.merchantName)
        XCTAssertNil(result.date)
    }

    func testDiscountLineIsNotAnItem() {
        let text = """
        スーパー
        牛乳 198
        割引 -50
        合計 148
        """
        let result = parser.parse(text, referenceDate: referenceDate)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.name, "牛乳")
        XCTAssertEqual(result.declaredTotal, 148)
        XCTAssertTrue(result.hasMismatch)
    }
}
