import XCTest
@testable import KakeiNote

final class ExpenseCSVExporterTests: XCTestCase {
    private func expense(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        title: String,
        amount: Int,
        category: ExpenseCategory,
        memo: String = "",
        merchantName: String? = nil,
        quantity: Int = 1,
        unitPrice: Int? = nil
    ) -> Expense {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        let date = KakeiCalendar.calendar.date(from: components)!
        return Expense(
            date: date,
            title: title,
            amount: amount,
            category: category,
            memo: memo,
            merchantName: merchantName,
            quantity: quantity,
            unitPrice: unitPrice,
            createdAt: date,
            updatedAt: date
        )
    }

    /// BOM と終端改行を除いた行配列（テスト用ヘルパー）。
    private func csvLines(_ csv: String) -> [String] {
        let withoutBOM = csv.hasPrefix(ExpenseCSVExporter.byteOrderMark)
            ? String(csv.dropFirst(ExpenseCSVExporter.byteOrderMark.count))
            : csv
        return withoutBOM
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: .newlines)
    }

    func testHeaderAndRows() {
        let csv = ExpenseCSVExporter.makeCSV([
            expense(year: 2026, month: 11, day: 23, title: "本　2冊　アピタ", amount: 1375, category: .other),
            expense(year: 2026, month: 11, day: 21, title: "牛乳", amount: 198, category: .food, memo: "スーパー", quantity: 1)
        ])

        let lines = csvLines(csv)

        XCTAssertEqual(lines[0], "日付,項目名,金額,カテゴリ,メモ,店舗名,数量,単価,登録日時,更新日時")
        // 日付の昇順に並ぶこと
        XCTAssertTrue(lines[1].hasPrefix("2026-11-21,牛乳,198,食料品,スーパー,,1,"))
        XCTAssertTrue(lines[2].hasPrefix("2026-11-23,本　2冊　アピタ,1375,その他,,,1,"))
        XCTAssertEqual(lines.count, 3)
    }

    func testBOMForExcel() {
        let csv = ExpenseCSVExporter.makeCSV([])
        XCTAssertTrue(csv.hasPrefix(ExpenseCSVExporter.byteOrderMark))
        // Excel が UTF-8 と判定できること（バイト先頭が EF BB BF）
        XCTAssertEqual(Array(csv.utf8.prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    func testEmptyExpensesProduceHeaderOnly() {
        let csv = ExpenseCSVExporter.makeCSV([])
        let lines = csvLines(csv)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0], ExpenseCSVExporter.headerFields.joined(separator: ","))
    }

    func testEscapingCommaQuoteAndNewline() {
        XCTAssertEqual(ExpenseCSVExporter.escape("お茶,緑茶"), "\"お茶,緑茶\"")
        XCTAssertEqual(ExpenseCSVExporter.escape("5\"棚"), "\"5\"\"棚\"")
        XCTAssertEqual(ExpenseCSVExporter.escape("1行目\n2行目"), "\"1行目\n2行目\"")
        XCTAssertEqual(ExpenseCSVExporter.escape("通常の項目"), "通常の項目")
        // メモに改行が入っていても、クォートされた 1 フィールドとして出力されること
        let csv = ExpenseCSVExporter.makeCSV([
            expense(year: 2026, month: 11, day: 23, title: "コーヒー", amount: 480, category: .dining, memo: "1杯目\n2杯目")
        ])
        XCTAssertTrue(csv.contains(",\"1杯目\n2杯目\","))

        // 項目名にカンマが入っていてもエスケープされること
        let commaCSV = ExpenseCSVExporter.makeCSV([
            expense(year: 2026, month: 11, day: 23, title: "お茶,緑茶", amount: 300, category: .food)
        ])
        XCTAssertTrue(commaCSV.contains("\"お茶,緑茶\""))
    }

    func testOptionalFieldsAndTimestamps() {
        let csv = ExpenseCSVExporter.makeCSV([
            expense(year: 2026, month: 11, day: 20, hour: 9, title: "卵", amount: 248, category: .food, merchantName: "スーパーABC", quantity: 2, unitPrice: 124)
        ])
        let line = csv
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .newlines)
            .components(separatedBy: .newlines)[1]

        let fields = line.components(separatedBy: ",")
        XCTAssertEqual(fields[0], "2026-11-20")
        XCTAssertEqual(fields[1], "卵")
        XCTAssertEqual(fields[2], "248")
        XCTAssertEqual(fields[3], "食料品")
        XCTAssertEqual(fields[4], "")
        XCTAssertEqual(fields[5], "スーパーABC")
        XCTAssertEqual(fields[6], "2")
        XCTAssertEqual(fields[7], "124")
        XCTAssertEqual(fields[8], "2026-11-20 09:00:00")
        XCTAssertEqual(fields[9], "2026-11-20 09:00:00")
    }

    func testWriteTemporaryFile() throws {
        let csv = ExpenseCSVExporter.makeCSV([
            expense(year: 2026, month: 11, day: 23, title: "テスト", amount: 100, category: .other)
        ])
        let date = KakeiCalendar.date(year: 2026, month: 11, day: 24)!
        let url = try ExpenseCSVExporter.writeTemporaryFile(csv: csv, date: date)

        XCTAssertEqual(url.lastPathComponent, "KakeiNote-支出一覧-2026-11-24.csv")
        // String(contentsOf:) は BOM を除去するため、バイト列で比較する
        XCTAssertEqual(try Data(contentsOf: url), csv.data(using: .utf8))

        try? FileManager.default.removeItem(at: url)
    }

    func testFileName() {
        XCTAssertEqual(
            ExpenseCSVExporter.fileName(date: KakeiCalendar.date(year: 2026, month: 1, day: 9)!),
            "KakeiNote-支出一覧-2026-01-09.csv"
        )
    }

    @MainActor
    func testAppModelExportProducesValidFile() throws {
        let stack = try CoreDataStack(inMemory: true)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KakeiNoteExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = AppModel(
            repository: ExpenseRepository(stack: stack),
            imageStore: ReceiptImageStore(directory: directory)
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        model.addExpense(
            title: "本　2冊　アピタ",
            amount: 1375,
            category: .other,
            date: KakeiCalendar.date(year: 2026, month: 11, day: 23)!
        )

        let url = model.makeExportFileURL()
        XCTAssertNotNil(url)
        let content = try String(contentsOf: url!, encoding: .utf8)
        XCTAssertTrue(content.contains("本　2冊　アピタ"))
        XCTAssertTrue(content.contains("1375"))
        XCTAssertNil(model.errorMessage)
    }
}
