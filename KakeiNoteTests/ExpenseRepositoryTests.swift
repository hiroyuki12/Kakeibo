import XCTest
import CoreData
@testable import KakeiNote

final class ExpenseRepositoryTests: XCTestCase {
    private func sampleExpense(
        id: UUID = UUID(),
        date: Date = KakeiCalendar.date(year: 2026, month: 11, day: 20)!,
        title: String = "牛乳",
        amount: Int = 198,
        category: ExpenseCategory = .food,
        memo: String = "",
        receiptImageName: String? = nil,
        receiptGroupID: UUID? = nil
    ) -> Expense {
        Expense(
            id: id,
            date: date,
            title: title,
            amount: amount,
            category: category,
            memo: memo,
            receiptImageName: receiptImageName,
            receiptGroupID: receiptGroupID
        )
    }

    func testInsertFetchAndCount() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        let expense = sampleExpense()

        try repository.upsert(expense)

        XCTAssertEqual(try repository.count(), 1)
        let fetched = try repository.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "牛乳")
        XCTAssertEqual(fetched.first?.amount, 198)
        XCTAssertEqual(fetched.first?.category, .food)
    }

    func testUpdateKeepsSingleRecord() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        let id = UUID()
        try repository.upsert(sampleExpense(id: id))

        var updated = sampleExpense(id: id)
        updated.title = "低脂肪牛乳"
        updated.amount = 228
        updated.category = .dailyGoods
        updated.memo = "特売"
        updated.date = KakeiCalendar.date(year: 2026, month: 11, day: 19)!
        updated.updatedAt = Date().addingTimeInterval(10)
        try repository.upsert(updated)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "低脂肪牛乳")
        XCTAssertEqual(all.first?.amount, 228)
        XCTAssertEqual(all.first?.category, .dailyGoods)
        XCTAssertEqual(all.first?.memo, "特売")
        XCTAssertEqual(all.first?.date, KakeiCalendar.date(year: 2026, month: 11, day: 19)!)
    }

    func testBatchInsertAndDelete() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        let group = UUID()
        let expenses = [
            sampleExpense(title: "牛乳", receiptGroupID: group),
            sampleExpense(title: "卵", amount: 248, receiptGroupID: group)
        ]

        try repository.upsert(expenses)
        XCTAssertEqual(try repository.count(), 2)
        XCTAssertTrue(try repository.fetchAll().allSatisfy { $0.receiptGroupID == group })

        try repository.delete(ids: expenses.map(\.id))
        XCTAssertEqual(try repository.count(), 0)
    }

    func testDeleteSingleRecord() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        let first = sampleExpense(title: "A")
        let second = sampleExpense(title: "B")
        try repository.upsert([first, second])

        try repository.delete(id: first.id)

        let remaining = try repository.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "B")
    }

    func testOptionalFieldsRoundTrip() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        let group = UUID()
        let expense = Expense(
            date: Date(),
            title: "レシート商品",
            amount: 598,
            category: .dailyGoods,
            memo: "スーパー",
            receiptImageName: "receipt.jpg",
            receiptGroupID: group,
            merchantName: "スーパーABC",
            quantity: 2,
            unitPrice: 299
        )
        try repository.upsert(expense)

        let fetched = try repository.fetchAll().first
        XCTAssertEqual(fetched?.receiptImageName, "receipt.jpg")
        XCTAssertEqual(fetched?.receiptGroupID, group)
        XCTAssertEqual(fetched?.merchantName, "スーパーABC")
        XCTAssertEqual(fetched?.quantity, 2)
        XCTAssertEqual(fetched?.unitPrice, 299)
        XCTAssertEqual(fetched?.isFromReceipt, true)
    }

    func testUnknownCategoryFallsBackToOther() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        try repository.upsert(sampleExpense(category: .food))

        // 保存済み文字列が壊れていても「その他」で復元されること
        let entityContext = stack.container.viewContext
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        let entities = try entityContext.fetch(request)
        entities.first?.category = "broken"
        try entityContext.save()

        XCTAssertEqual(try repository.fetchAll().first?.category, .other)
    }

    func testSQLitePersistenceAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KakeiNoteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("KakeiNote.sqlite")
        let expenseID = UUID()

        try autoreleasepool {
            let stack = try CoreDataStack(storeURL: storeURL)
            let repository = ExpenseRepository(stack: stack)
            try repository.upsert(sampleExpense(id: expenseID, memo: "永続化テスト"))
            XCTAssertEqual(try repository.count(), 1)
            try closeStores(of: stack)
        }

        // autoreleasepool 内で開くことで、defer のディレクトリ削除前に
        // SQLite 接続が閉じる（libsqlite3 の vnode 警告を防ぐ）。
        try autoreleasepool {
            let reopenedStack = try CoreDataStack(storeURL: storeURL)
            let reopenedRepository = ExpenseRepository(stack: reopenedStack)
            let all = try reopenedRepository.fetchAll()

            XCTAssertEqual(all.count, 1)
            XCTAssertEqual(all.first?.id, expenseID)
            XCTAssertEqual(all.first?.title, "牛乳")
            XCTAssertEqual(all.first?.memo, "永続化テスト")
            try closeStores(of: reopenedStack)
        }
    }

    /// Core Data のストアを明示的に閉じる。プールの解放だけでは
    /// SQLite ハンドルが残ることがあり、一時ディレクトリ削除時に
    /// libsqlite3 の "vnode unlinked while in use" 警告が出るため。
    private func closeStores(of stack: CoreDataStack) throws {
        for store in stack.container.persistentStoreCoordinator.persistentStores {
            try stack.container.persistentStoreCoordinator.remove(store)
        }
    }

    func testDeleteAll() throws {
        let stack = try CoreDataStack(inMemory: true)
        let repository = ExpenseRepository(stack: stack)
        try repository.upsert([sampleExpense(title: "A"), sampleExpense(title: "B")])
        XCTAssertEqual(try repository.count(), 2)

        try repository.deleteAll()
        XCTAssertEqual(try repository.count(), 0)
    }
}
