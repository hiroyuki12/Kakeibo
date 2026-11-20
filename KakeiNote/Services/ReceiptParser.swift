import Foundation

/// レシート OCR のテキストを行単位で解析し、店舗名・日付・合計・明細を推定する。
/// 完璧な解析より「確認画面で直せる初期値」を出すことを重視したヒューリスティック。
struct ReceiptParser {
    var classifier: CategoryClassifier
    var calendar: Calendar

    init(classifier: CategoryClassifier = .default, calendar: Calendar = KakeiCalendar.calendar) {
        self.classifier = classifier
        self.calendar = calendar
    }

    func parse(_ rawText: String, referenceDate: Date = Date()) -> ParsedReceipt {
        let normalized = TextNormalizer.normalize(rawText)
        let lines = normalized
            .components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty && !isSeparator($0) }

        guard !lines.isEmpty else {
            return ParsedReceipt(
                merchantName: nil, date: nil, declaredTotal: nil, subtotal: nil,
                items: [], rawText: normalized
            )
        }

        let merchant = extractMerchant(from: lines)
        let date = extractDate(from: lines, referenceDate: referenceDate)
        let totals = extractTotals(from: lines)
        let items = extractItems(from: lines, merchant: merchant)

        let declaredTotal = totals.total ?? totals.subtotal
        return ParsedReceipt(
            merchantName: merchant,
            date: date,
            declaredTotal: declaredTotal,
            subtotal: totals.subtotal,
            items: items,
            rawText: normalized
        )
    }

    // MARK: - 行の整形

    private func cleanLine(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(
            of: #"^[＊*※・●○◎■□◆◇☆★\-–—=＿_]+\s*"#,
            with: "",
            options: .regularExpression
        )
        line = line.replacingOccurrences(of: #"\s{3,}"#, with: "  ", options: .regularExpression)
        return line
    }

    private func isSeparator(_ line: String) -> Bool {
        line.rangeOfCharacter(from: .letters) == nil && line.rangeOfCharacter(from: .decimalDigits) == nil
    }

    // MARK: - 日付

    private func extractDate(from lines: [String], referenceDate: Date) -> Date? {
        for line in lines {
            if let date = date(in: line, referenceDate: referenceDate) {
                return date
            }
        }
        return nil
    }

    private func date(in line: String, referenceDate: Date) -> Date? {
        // 2026年11月20日 / 2026/11/20 / 2026.11.20
        if let groups = firstMatch(#"(20[0-9]{2})\s*[年/.\-]\s*([0-9]{1,2})\s*[月/.\-]\s*([0-9]{1,2})"#, in: line),
           groups.count >= 4,
           let year = Int(groups[1]), let month = Int(groups[2]), let day = Int(groups[3]) {
            return makeDate(year: year, month: month, day: day)
        }

        // 令和8年11月20日
        if let groups = firstMatch(#"令和\s*([0-9]{1,2})\s*[年/.]\s*([0-9]{1,2})\s*[月/.]\s*([0-9]{1,2})"#, in: line),
           groups.count >= 4,
           let reiwa = Int(groups[1]), let month = Int(groups[2]), let day = Int(groups[3]) {
            return makeDate(year: 2018 + reiwa, month: month, day: day)
        }

        // R8.11.20
        if let groups = firstMatch(#"(?:R|ｒ)\s*([0-9]{1,2})\s*[./]\s*([0-9]{1,2})\s*[./]\s*([0-9]{1,2})"#, in: line),
           groups.count >= 4,
           let reiwa = Int(groups[1]), let month = Int(groups[2]), let day = Int(groups[3]) {
            return makeDate(year: 2018 + reiwa, month: month, day: day)
        }

        // 11月20日 / 11/20（年なし）
        if let groups = firstMatch(#"(?<![0-9])([0-9]{1,2})\s*[月/]\s*([0-9]{1,2})\s*日?(?![0-9])"#, in: line),
           groups.count >= 3,
           let month = Int(groups[1]), let day = Int(groups[2]) {
            let current = calendar.component(.year, from: referenceDate)
            if let candidate = makeDate(year: current, month: month, day: day) {
                let threshold = calendar.date(byAdding: .day, value: 40, to: referenceDate) ?? referenceDate
                if candidate > threshold {
                    return makeDate(year: current - 1, month: month, day: day)
                }
                return candidate
            }
        }
        return nil
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        guard (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == year, verified.month == month, verified.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    // MARK: - 店舗名

    private func extractMerchant(from lines: [String]) -> String? {
        let candidates = Array(lines.prefix(8))
        let storeMarkers = [
            "スーパー", "マート", "ストア", "薬局", "ドラッグ", "カフェ", "喫茶",
            "レストラン", "食堂", "ベーカリー", "コンビニ", "売店", "市場", "百貨店",
            "デパート", "店"
        ]

        for line in candidates where !isNoise(line) && !isTotalLine(line) && !isSubtotalLine(line) {
            guard line.rangeOfCharacter(from: .letters) != nil, !line.contains("¥") else { continue }
            if line.rangeOfCharacter(from: .decimalDigits) != nil && line.count <= 4 { continue }
            let name = cleanItemName(line)
            guard name.count >= 2, name.count <= 40 else { continue }
            if storeMarkers.contains(where: { name.contains($0) }) {
                return name
            }
        }

        for line in candidates where !isNoise(line) && !isTotalLine(line) && !isSubtotalLine(line) {
            guard line.rangeOfCharacter(from: .letters) != nil, !line.contains("¥") else { continue }
            if date(in: line, referenceDate: Date()) != nil { continue }
            let name = cleanItemName(line)
            guard name.count >= 2, name.count <= 30 else { continue }
            if name.rangeOfCharacter(from: .decimalDigits) != nil && name.count <= 5 { continue }
            if name.hasSuffix("様") || name.hasSuffix("御中") { continue }
            return name
        }
        return nil
    }

    // MARK: - 合計・小計

    private func extractTotals(from lines: [String]) -> (total: Int?, subtotal: Int?) {
        var candidates: [(priority: Int, amount: Int, index: Int)] = []
        var subtotal: Int?

        for (index, line) in lines.enumerated() {
            guard !line.contains("点数"), !isTaxLine(line), !isPaymentLine(line) else { continue }

            if isTotalLine(line) {
                var amount = lastAmount(in: line)
                if amount == nil, index + 1 < lines.count {
                    amount = amountOnly(lines[index + 1])
                }
                if let amount, amount > 0, amount < 100_000_000 {
                    let priority = line.contains("税込") || line.contains("総計") || line.contains("お会計")
                        || line.contains("お買上") || line.contains("ご利用金額")
                        ? 3 : 2
                    candidates.append((priority, amount, index))
                }
            } else if isSubtotalLine(line) {
                if let amount = lastAmount(in: line) {
                    subtotal = amount
                }
            }
        }

        let best = candidates.max { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.index < rhs.index
        }
        return (best?.amount, subtotal)
    }

    // MARK: - 明細

    private func extractItems(from lines: [String], merchant: String?) -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        var pendingName: String?

        for (index, line) in lines.enumerated() {
            if index < 8 && date(in: line, referenceDate: Date()) != nil {
                continue
            }
            if isTotalLine(line) || isSubtotalLine(line) || isTaxLine(line) || isPaymentLine(line) {
                pendingName = nil
                continue
            }
            if isNoise(line) {
                pendingName = nil
                continue
            }

            // 単価・数量だけの行。金額が併記されていれば直前の商品名に紐づける。
            if isUnitPriceLine(line) {
                if line.contains("金額"),
                   let amount = lastAmount(in: line),
                   let name = pendingName,
                   amount > 0 {
                    items.append(makeItem(name: name, amount: amount, quantity: 1, unitPrice: nil, line: line, merchant: merchant))
                    pendingName = nil
                }
                continue
            }

            if let amount = amountOnly(line) {
                if let name = pendingName {
                    items.append(makeItem(name: name, amount: amount, quantity: 1, unitPrice: nil, line: line, merchant: merchant))
                }
                pendingName = nil
                continue
            }

            if let parsed = parseItemLine(line) {
                items.append(makeItem(
                    name: parsed.name,
                    amount: parsed.amount,
                    quantity: parsed.quantity,
                    unitPrice: parsed.unitPrice,
                    line: line,
                    merchant: merchant
                ))
                pendingName = nil
                continue
            }

            if isPendingNameCandidate(line) {
                pendingName = cleanItemName(line)
            }
        }

        return Array(items.prefix(80))
    }

    private struct ParsedLineItem {
        let name: String
        let amount: Int
        let quantity: Int
        let unitPrice: Int?
    }

    private func parseItemLine(_ line: String) -> ParsedLineItem? {
        if isNoise(line) || isTotalLine(line) || isSubtotalLine(line) || isTaxLine(line) {
            return nil
        }
        // 住所らしき行は除外
        if line.contains("〒") { return nil }
        if line.range(of: #"(?:都|道|府|県).*(?:市|区|町|村).*[0-9]"#, options: .regularExpression) != nil {
            return nil
        }

        let tokens = numberTokens(in: line)
        let priceTokens = tokens.filter { isPriceCandidate($0, in: line) }
        guard let amountToken = priceTokens.last, amountToken.value > 0 else { return nil }

        let nsLine = line as NSString
        let namePart = nsLine.substring(to: amountToken.range.location)
        var name = cleanItemName(namePart)
        guard isValidItemName(name) else { return nil }

        // ¥ も通貨表記もない 1 桁金額は住所・店番の誤検出が多いので除外
        if amountToken.value < 10 && !line.contains("¥") && !line.contains("円") {
            return nil
        }
        // 店舗名行（〜店 + 小さい数字）を商品として拾わない
        if line.hasSuffix("店") && amountToken.value < 100 && !line.contains("¥") {
            return nil
        }

        let quantityInfo = detectQuantity(in: line, amount: amountToken.value)
        if quantityInfo.quantity > 1, quantityInfo.unitPrice != nil {
            name = name.replacingOccurrences(of: #"[0-9]{1,3}\s*(?:点|個|枚|本|袋|箱|パック|缶|包)\s*$"#,
                                             with: "", options: .regularExpression)
        }

        return ParsedLineItem(
            name: name,
            amount: amountToken.value,
            quantity: quantityInfo.quantity,
            unitPrice: quantityInfo.unitPrice
        )
    }

    private func makeItem(
        name: String,
        amount: Int,
        quantity: Int,
        unitPrice: Int?,
        line: String,
        merchant: String?
    ) -> ParsedReceiptItem {
        let category = classifier.category(for: name, merchantName: merchant)
        return ParsedReceiptItem(
            name: name,
            amount: amount,
            quantity: max(1, quantity),
            unitPrice: unitPrice,
            category: category
        )
    }

    private func detectQuantity(in line: String, amount: Int) -> (quantity: Int, unitPrice: Int?) {
        // @198 x 2
        if let groups = firstMatch(#"@\s*¥?\s*([0-9,]+)\s*[x×]\s*([0-9]{1,3})"#, in: line),
           groups.count >= 3,
           let unit = Int(groups[1].replacingOccurrences(of: ",", with: "")),
           let quantity = Int(groups[2]), quantity > 0 {
            return (quantity, unit)
        }
        // 2 x 198
        if let groups = firstMatch(#"([0-9]{1,3})\s*[x×]\s*@?\s*¥?\s*([0-9,]+)"#, in: line),
           groups.count >= 3,
           let quantity = Int(groups[1]),
           let unit = Int(groups[2].replacingOccurrences(of: ",", with: "")),
           quantity > 0, quantity <= 999 {
            return (quantity, unit)
        }
        // 2点 / 2個
        if let groups = firstMatch(#"([0-9]{1,3})\s*(?:点|個|枚|本|袋|箱|パック|缶|包)"#, in: line),
           groups.count >= 2,
           let quantity = Int(groups[1]), quantity > 0 {
            return (quantity, nil)
        }
        return (1, nil)
    }

    // MARK: - 判定ヘルパー

    private func isTotalLine(_ line: String) -> Bool {
        let key = line.lowercased()
        if key.contains("点数") { return false }
        let patterns = ["合計", "総計", "お会計", "お買上", "お買上げ", "ご利用金額", "請求金額"]
        return patterns.contains { key.contains($0) }
    }

    private func isSubtotalLine(_ line: String) -> Bool {
        line.contains("小計")
    }

    private func isTaxLine(_ line: String) -> Bool {
        let key = line.lowercased()
        let patterns = ["消費税", "税額", "内税", "外税", "軽減税率", "税率", "課税", "非課税", "税込対象", "税抜対象"]
        return patterns.contains { key.contains($0) }
    }

    private func isPaymentLine(_ line: String) -> Bool {
        let key = line.lowercased()
        let patterns = [
            "お預", "預り", "預かり", "お釣", "釣銭", "つり", "現金", "クレジット",
            "電子マネー", "paypay", "楽天ペイ", "d払い", "au pay", "line pay",
            "支払", "ポイント", "残高", "カード", "領収"
        ]
        return patterns.contains { key.contains($0) }
    }

    private func isNoise(_ line: String) -> Bool {
        let key = line.lowercased()
        let patterns = [
            "電話", "tel", "fax", "ファックス", "〒", "住所", "レジ", "担当",
            "登録番号", "領収書", "レシート", "伝票", "ご来店", "ありがとう",
            "営業時間", "店舗情報", "お問い合わせ", "会員", "ポイント", "残高",
            "お預", "預り", "預かり", "お釣", "釣銭", "現金", "クレジット",
            "電子マネー", "paypay", "楽天ペイ", "d払い", "au pay", "line pay",
            "支払", "消費税", "税額", "内税", "外税", "軽減税率", "対象",
            "割引", "値引", "クーポン", "レジ袋", "お買上点数", "点数", "買上点数",
            "レジ番号", "レジno", "no.", "番号", "登録", "レシート番号",
            "tポイント", "楽天ポイント", "dポイント", "ponta", "paypayポイント"
        ]
        if patterns.contains(where: { key.contains($0) }) { return true }
        if line.range(of: #"^0[0-9]{1,4}-[0-9]{1,4}-[0-9]{3,4}$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func isUnitPriceLine(_ line: String) -> Bool {
        let key = line.lowercased()
        if key.contains("単価") || key.contains("数量") || key.contains("点数") { return true }
        if line.range(of: #"^[0-9]{1,3}\s*[x×]\s*[¥]?\s*[0-9,]+\s*$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func isPendingNameCandidate(_ line: String) -> Bool {
        let name = cleanItemName(line)
        guard isValidItemName(name) else { return false }
        guard !isNoise(line), !isTotalLine(line), !isSubtotalLine(line), !isTaxLine(line) else { return false }
        if name.contains("単価") || name.contains("数量") || name.contains("金額") { return false }
        // 店舗名だけの行は「次の行の金額」と結びつけない
        let storeMarkers = ["スーパー", "マート", "ストア", "薬局", "ドラッグ", "カフェ", "レストラン", "食堂", "コンビニ"]
        if storeMarkers.contains(where: { name.contains($0) }) { return false }
        if name.hasSuffix("店") && name.count <= 30 { return false }
        return true
    }

    private func isValidItemName(_ name: String) -> Bool {
        guard name.count >= 1, name.count <= 50 else { return false }
        guard name.rangeOfCharacter(from: .letters) != nil else { return false }
        if name.contains("合計") || name.contains("小計") || name.contains("消費税") { return false }
        if isNoise(name) { return false }
        return true
    }

    private func cleanItemName(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns: [(String, String)] = [
            (#"^[0-9]{4,}\s+"#, ""),
            (#"^[＊*※・●○◎■□◆◇☆★\-–—:：|=＿_]+\s*"#, ""),
            (#"[（(]\s*(?:税込|税抜|軽減?|8%|10%|非課税)\s*[)）]"#, ""),
            (#"@\s*[¥]?\s*[0-9,]+\s*(?=x|×|=|\s*$)"#, ""),
            (#"[0-9]{1,3}\s*[x×]\s*@?\s*[¥]?\s*[0-9,]+\s*(?==|\s*$)"#, ""),
            (#"\s*[¥]\s*$"#, ""),
            (#"[0-9]{1,3}\s*(?:点|個|枚|本|袋|箱|パック|缶|包)\s*(?=@|[x×=]|\s*$)"#, ""),
            (#"[¥]\s*[0-9,]+\s*$"#, ""),
            (#"[\s*※]+$"#, "")
        ]
        for (pattern, replacement) in patterns {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        text = text.replacingOccurrences(of: #"[\s:：|\-–—=]+$"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 数値抽出

    private struct NumberToken {
        let value: Int
        let raw: String
        let range: NSRange
    }

    private func numberTokens(in line: String) -> [NumberToken] {
        let nsLine = line as NSString
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![0-9])([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?![0-9])"
        ) else { return [] }

        return regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length)).compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let raw = nsLine.substring(with: match.range(at: 1))
            guard let value = Int(raw.replacingOccurrences(of: ",", with: "")) else { return nil }
            return NumberToken(value: value, raw: raw, range: match.range(at: 1))
        }
    }

    private func isPriceCandidate(_ token: NumberToken, in line: String) -> Bool {
        guard token.value > 0, token.raw.filter({ $0.isNumber }).count <= 7 else { return false }
        let nsLine = line as NSString

        let suffixStart = NSMaxRange(token.range)
        var suffix = suffixStart < nsLine.length ? nsLine.substring(from: suffixStart) : ""
        suffix = suffix.trimmingCharacters(in: .whitespaces)
        if let next = suffix.first {
            if "年月日時分%/-:".contains(next) { return false }
            if "点個枚本袋箱入巻包缶".contains(next) { return false }
            if next.isLetter && next != "円" { return false }
        }

        let prefix = nsLine.substring(to: token.range.location).trimmingCharacters(in: .whitespaces)
        if let last = prefix.last {
            if "@×xX*".contains(last) { return false }
            if last == "/" || last == "-" || last == ":" { return false }
        }
        return true
    }

    private func lastAmount(in line: String) -> Int? {
        numberTokens(in: line)
            .filter { isPriceCandidate($0, in: line) }
            .last?.value
    }

    private func amountOnly(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(
            of: #"^[¥]?\s*[0-9]{1,3}(?:,[0-9]{3})*\s*円?$"#,
            options: .regularExpression
        ) != nil else { return nil }
        guard let amount = lastAmount(in: trimmed), amount > 0 else { return nil }
        if amount < 10 && !trimmed.contains("¥") { return nil }
        return amount
    }

    // MARK: - 正規表現

    /// 最初のマッチを [全体, グループ1, グループ2, ...] で返す。
    private func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { nsText.substring(with: match.range(at: $0)) }
    }
}
