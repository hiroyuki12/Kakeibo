import Foundation

/// 支出データを CSV（UTF-8 BOM 付き・RFC 4180 準拠）へ書き出す。
/// アプリの削除や機種変更に備えたバックアップ手段として、全支出を Excel 等で
/// 開ける形式で出力する。
enum ExpenseCSVExporter {
    /// Excel で日本語が正しく開けるよう BOM を付ける。
    static let byteOrderMark = "\u{FEFF}"

    static let headerFields = [
        "日付", "項目名", "金額", "カテゴリ", "メモ", "店舗名", "数量", "単価",
        "登録日時", "更新日時",
    ]

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// 全支出を CSV 文字列へ変換する。日付の昇順（同日内は登録順）。
    static func makeCSV(_ expenses: [Expense]) -> String {
        var lines: [String] = [headerFields.joined(separator: ",")]

        let sorted = expenses.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.createdAt < rhs.createdAt
        }

        for expense in sorted {
            let fields = [
                dayFormatter.string(from: expense.date),
                expense.title,
                String(expense.amount),
                expense.category.displayName,
                expense.memo,
                expense.merchantName ?? "",
                String(expense.quantity),
                expense.unitPrice.map(String.init) ?? "",
                timestampFormatter.string(from: expense.createdAt),
                timestampFormatter.string(from: expense.updatedAt),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }

        // RFC 4180 準拠の改行コード
        return byteOrderMark + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// カンマ・ダブルクォート・改行を含むフィールドはクォートで囲み、
    /// 内部のクォートは二重化する。
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") ||
            field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// 書き出し用の一時ファイル名（例: KakeiNote-支出一覧-2026-11-24.csv）。
    static func fileName(date: Date = Date()) -> String {
        let stamp = dayFormatter.string(from: date)
        return "KakeiNote-支出一覧-\(stamp).csv"
    }

    /// CSV を一時ファイルに書き出し、共有シートに渡す URL を返す。
    static func writeTemporaryFile(csv: String, date: Date = Date()) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(date: date))
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}
