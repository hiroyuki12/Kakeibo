import Foundation
import UIKit

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let symbol: String

    init(text: String, symbol: String = "checkmark.circle.fill") {
        self.text = text
        self.symbol = symbol
    }
}

/// アプリ全体の状態。Core Data の変更後に必ず配列を再取得し、カレンダーと合計を即時反映する。
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published var toast: ToastMessage?
    @Published var errorMessage: String?

    let repository: ExpenseRepository
    let imageStore: ReceiptImageStore

    private var toastTask: Task<Void, Never>?

    convenience init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-UITEST_IN_MEMORY")
        do {
            let stack = try CoreDataStack(inMemory: isUITesting)
            self.init(repository: ExpenseRepository(stack: stack), imageStore: ReceiptImageStore())
        } catch {
            let stack = try! CoreDataStack(inMemory: true)
            self.init(repository: ExpenseRepository(stack: stack), imageStore: ReceiptImageStore())
            self.errorMessage = "データベースを開けなかったため、一時モードで起動しました。"
        }
        if arguments.contains("-UITEST_SEED") {
            seedSampleDataForUITests()
        }
    }

    /// スクリーンショット・UI テスト用のサンプルデータ。通常起動では呼ばれない。
    private func seedSampleDataForUITests() {
        guard expenses.isEmpty else { return }
        let calendar = KakeiCalendar.calendar
        let today = KakeiCalendar.startOfDay(Date())
        let monthStart = KakeiCalendar.startOfMonth(today)
        let days = KakeiCalendar.daysInMonth(of: monthStart)
        let todayDay = calendar.component(.day, from: today)

        let samples: [(Int, String, Int, ExpenseCategory)] = [
            (0, "スーパーで買い物", 2480, .food),
            (0, "ドラッグストア", 860, .dailyGoods),
            (-1, "ランチ", 1280, .dining),
            (-1, "電車", 420, .transport),
            (-2, "コーヒー", 480, .dining),
            (-3, "薬局", 1180, .medical),
            (-5, "Tシャツ", 2980, .clothing),
            (-6, "映画", 1900, .entertainment),
            (-8, "電気料金", 7420, .utilities),
            (-9, "携帯電話料金", 3980, .communication),
            (-11, "スーパーで買い物", 3260, .food),
            (-14, "ガソリン", 4500, .transport)
        ]

        for (offset, title, amount, category) in samples {
            let day = max(1, min(days, todayDay + offset))
            guard let date = calendar.date(byAdding: .day, value: day - todayDay, to: today) else { continue }
            addExpense(title: title, amount: amount, category: category, date: date)
        }
        errorMessage = nil
        toast = nil
    }

    init(repository: ExpenseRepository, imageStore: ReceiptImageStore) {
        self.repository = repository
        self.imageStore = imageStore
        reload()
        imageStore.removeOrphans(referencedNames: Set(expenses.compactMap(\.receiptImageName)))
    }

    // MARK: - 読み込み

    func reload() {
        do {
            expenses = try repository.fetchAll()
        } catch {
            present(error, prefix: "支出の読み込みに失敗しました")
        }
    }

    // MARK: - 追加・更新・削除

    @discardableResult
    func addExpense(
        title: String,
        amount: Int,
        category: ExpenseCategory,
        date: Date,
        memo: String = "",
        receiptImageName: String? = nil,
        receiptGroupID: UUID? = nil,
        merchantName: String? = nil,
        quantity: Int = 1,
        unitPrice: Int? = nil
    ) -> Expense? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showError("項目名を入力してください。")
            return nil
        }
        guard amount > 0 else {
            showError("金額を入力してください。")
            return nil
        }

        let expense = Expense(
            date: date,
            title: trimmedTitle,
            amount: amount,
            category: category,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImageName: receiptImageName,
            receiptGroupID: receiptGroupID,
            merchantName: merchantName,
            quantity: quantity,
            unitPrice: unitPrice
        )

        do {
            try repository.upsert(expense)
            reload()
            showToast("支出を登録しました")
            return expense
        } catch {
            present(error, prefix: "支出を保存できませんでした")
            return nil
        }
    }

    @discardableResult
    func updateExpense(
        _ expense: Expense,
        title: String,
        amount: Int,
        category: ExpenseCategory,
        date: Date,
        memo: String
    ) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showError("項目名を入力してください。")
            return false
        }
        guard amount > 0 else {
            showError("金額を入力してください。")
            return false
        }

        var updated = expense
        updated.title = trimmedTitle
        updated.amount = amount
        updated.category = category
        updated.date = KakeiCalendar.startOfDay(date)
        updated.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()

        do {
            try repository.upsert(updated)
            reload()
            showToast("支出を更新しました")
            return true
        } catch {
            present(error, prefix: "支出を更新できませんでした")
            return false
        }
    }

    func deleteExpense(_ expense: Expense) {
        let imageName = expense.receiptImageName
        do {
            try repository.delete(id: expense.id)
            reload()
            if let imageName,
               !expenses.contains(where: { $0.receiptImageName == imageName }) {
                imageStore.delete(named: imageName)
            }
            showToast("支出を削除しました")
        } catch {
            present(error, prefix: "支出を削除できませんでした")
        }
    }

    /// レシートの明細をまとめて登録する。全明細でレシート画像とグループIDを共有する。
    @discardableResult
    func addReceiptItems(
        _ items: [ReceiptDraftItem],
        merchantName: String?,
        date: Date,
        receiptImageName: String?
    ) -> Int {
        let validItems = items.filter { $0.amount > 0 && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validItems.isEmpty else {
            showError("登録する明細がありません。金額と項目名を確認してください。")
            return 0
        }

        let groupID = UUID()
        let baseDate = KakeiCalendar.startOfDay(date)
        let now = Date()
        let expensesToSave = validItems.enumerated().map { index, item in
            Expense(
                date: baseDate,
                title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: item.amount,
                category: item.category,
                memo: merchantName ?? "レシートから登録",
                receiptImageName: receiptImageName,
                receiptGroupID: groupID,
                merchantName: merchantName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                createdAt: now.addingTimeInterval(Double(index) / 1_000),
                updatedAt: now
            )
        }

        do {
            try repository.upsert(expensesToSave)
            reload()
            // シートを閉じるアニメーションがあるため、通常より長めに表示する
            showToast("\(expensesToSave.count)件を登録しました", duration: 3.5)
            return expensesToSave.count
        } catch {
            present(error, prefix: "レシートの支出を保存できませんでした")
            return 0
        }
    }

    // MARK: - 参照

    func expenses(on day: Date) -> [Expense] {
        expenses
            .filter { KakeiCalendar.isSameDay($0.date, day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func statistics(for month: Date) -> MonthStatistics {
        MonthStatistics(expenses: expenses, month: month)
    }

    func todayExpenses() -> [Expense] {
        expenses(on: Date())
    }

    func todayTotal() -> Int {
        expenses(on: Date()).reduce(0) { $0 + $1.amount }
    }

    func receiptImage(named name: String?) -> UIImage? {
        guard let name else { return nil }
        return imageStore.image(named: name)
    }

    func isReceiptImageReferenced(_ name: String) -> Bool {
        expenses.contains { $0.receiptImageName == name }
    }

    // MARK: - レシート画像

    @discardableResult
    func saveReceiptImage(_ image: UIImage) throws -> String {
        try imageStore.save(image)
    }

    func discardReceiptImage(named name: String?) {
        guard let name, !isReceiptImageReferenced(name) else { return }
        imageStore.delete(named: name)
    }

    // MARK: - CSV 書き出し（バックアップ）

    /// 全支出を CSV に書き出し、共有用の一時ファイル URL を返す。
    /// 失敗した場合はエラーを表示して nil を返す。
    @discardableResult
    func makeExportFileURL() -> URL? {
        let csv = ExpenseCSVExporter.makeCSV(expenses)
        do {
            return try ExpenseCSVExporter.writeTemporaryFile(csv: csv)
        } catch {
            present(error, prefix: "CSVの書き出しに失敗しました")
            return nil
        }
    }

    // MARK: - 通知

    func showToast(
        _ text: String,
        symbol: String = "checkmark.circle.fill",
        duration: TimeInterval = 2.2
    ) {
        let message = ToastMessage(text: text, symbol: symbol)
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self?.toast?.id == message.id {
                self?.toast = nil
            }
        }
    }

    func showError(_ message: String) {
        errorMessage = message
    }

    private func present(_ error: Error, prefix: String) {
        errorMessage = "\(prefix): \(error.localizedDescription)"
    }
}
