import Foundation

/// 日本円の表示・入力補助。
enum JPYFormat {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let compactFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    /// ¥1,234
    static func yen(_ amount: Int) -> String {
        "¥" + plain(amount)
    }

    /// 1,234
    static func plain(_ amount: Int) -> String {
        numberFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// カレンダーの狭いマス用。大きな金額は「¥12.3万」に短縮する。
    static func compact(_ amount: Int) -> String {
        if amount >= 1_000_000 {
            let value = Double(amount) / 10_000
            let text = compactFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "¥\(text)万"
        }
        return yen(amount)
    }

    /// 入力文字列から数字だけを取り出す（全角数字にも対応）。
    static func digits(from text: String) -> String {
        let normalized = text.precomposedStringWithCompatibilityMapping
        return normalized.filter { $0.isASCII && $0.isNumber }
    }

    /// 数字列を3桁区切りにする。空文字は空文字のまま。
    static func grouped(_ digits: String) -> String {
        let trimmed = String(digits.drop { $0 == "0" })
        guard !trimmed.isEmpty else { return digits.isEmpty ? "" : "0" }
        var result: [Character] = []
        let reversed = Array(trimmed.reversed())
        for (index, character) in reversed.enumerated() {
            if index > 0 && index % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return String(result.reversed())
    }

    /// 表示用文字列（¥ やカンマを含む）から金額を取り出す。
    static func amount(from text: String) -> Int {
        let digits = digits(from: text)
        guard !digits.isEmpty else { return 0 }
        // Int の範囲を超える入力は 0 として扱う
        guard let value = Int(digits), value <= 99_999_999_999 else { return 0 }
        return value
    }

    /// 入力中の文字列を「カンマ区切りの数字」に整形する。
    static func formattedInput(_ text: String) -> String {
        let digits = digits(from: text)
        guard !digits.isEmpty else { return "" }
        let significant = digits.drop { $0 == "0" }
        if significant.isEmpty { return "0" }
        return grouped(String(significant))
    }
}

/// 日本語の日付ラベル。
enum DateLabels {
    static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "M月d日（E）"
        return formatter
    }()

    private static let fullDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = KakeiCalendar.calendar
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    static func monthTitle(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func monthShort(_ date: Date) -> String {
        monthShortFormatter.string(from: date)
    }

    static func dayTitle(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func fullDayTitle(_ date: Date) -> String {
        fullDayFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func weekdayIndex(of date: Date) -> Int {
        KakeiCalendar.calendar.component(.weekday, from: date) - 1
    }
}

/// テキスト正規化。OCR の全角数字・記号揺れを吸収する。
enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        text
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\u{00A5}", with: "¥")
            .replacingOccurrences(of: "￥", with: "¥")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "‐", with: "-")
            .replacingOccurrences(of: "‑", with: "-")
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }

    /// 比較用に空白・記号を落とした小文字文字列。
    static func searchKey(_ text: String) -> String {
        normalize(text)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }
}
