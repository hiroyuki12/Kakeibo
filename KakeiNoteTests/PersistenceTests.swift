import XCTest
import UIKit
@testable import KakeiNote

final class ReceiptImageStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KakeiNoteImageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeImage(size: CGSize = CGSize(width: 200, height: 120)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 20, y: 20, width: 100, height: 30))
        }
    }

    func testSaveLoadDelete() throws {
        let store = ReceiptImageStore(directory: directory)
        let name = try store.save(makeImage())

        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertTrue(store.exists(named: name))
        XCTAssertNotNil(store.image(named: name))

        store.delete(named: name)
        XCTAssertFalse(store.exists(named: name))
        XCTAssertNil(store.image(named: name))
    }

    func testRejectsPathTraversalNames() {
        let store = ReceiptImageStore(directory: directory)
        XCTAssertNil(store.image(named: "../evil.jpg"))
        XCTAssertNil(store.image(named: "a/b.jpg"))
        XCTAssertFalse(store.exists(named: "../evil.jpg"))
        store.delete(named: "../evil.jpg")
    }

    func testRemoveOrphans() throws {
        let store = ReceiptImageStore(directory: directory)
        let keep = try store.save(makeImage())
        let orphan = try store.save(makeImage())

        store.removeOrphans(referencedNames: [keep])

        XCTAssertTrue(store.exists(named: keep))
        XCTAssertFalse(store.exists(named: orphan))
    }
}

final class AppModelTests: XCTestCase {
    @MainActor
    private func makeModel() throws -> (AppModel, ReceiptImageStore) {
        let stack = try CoreDataStack(inMemory: true)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KakeiNoteModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageStore = ReceiptImageStore(directory: directory)
        let repository = ExpenseRepository(stack: stack)
        let model = AppModel(repository: repository, imageStore: imageStore)
        return (model, imageStore)
    }

    @MainActor
    func testAddUpdateDeleteAndAggregate() throws {
        let (model, _) = try makeModel()
        let today = Date()

        let added = model.addExpense(
            title: "テスト購入",
            amount: 1280,
            category: .food,
            date: today,
            memo: "メモ"
        )

        XCTAssertNotNil(added)
        XCTAssertEqual(model.expenses.count, 1)
        XCTAssertEqual(model.todayTotal(), 1280)
        XCTAssertEqual(model.expenses(on: today).first?.title, "テスト購入")
        XCTAssertEqual(model.statistics(for: today).total, 1280)

        guard let added else { return }
        let updated = model.updateExpense(
            added,
            title: "更新後",
            amount: 1500,
            category: .dining,
            date: today,
            memo: "更新メモ"
        )
        XCTAssertTrue(updated)
        XCTAssertEqual(model.expenses.count, 1)
        XCTAssertEqual(model.expenses.first?.amount, 1500)
        XCTAssertEqual(model.expenses.first?.category, .dining)
        XCTAssertEqual(model.expenses.first?.memo, "更新メモ")
        XCTAssertEqual(model.todayTotal(), 1500)

        model.deleteExpense(model.expenses[0])
        XCTAssertTrue(model.expenses.isEmpty)
        XCTAssertEqual(model.todayTotal(), 0)
    }

    @MainActor
    func testValidationRejectsEmptyTitleAndZeroAmount() throws {
        let (model, _) = try makeModel()

        let emptyTitle = model.addExpense(title: "   ", amount: 100, category: .food, date: Date())
        XCTAssertNil(emptyTitle)
        XCTAssertNotNil(model.errorMessage)
        model.errorMessage = nil

        let zeroAmount = model.addExpense(title: "test", amount: 0, category: .food, date: Date())
        XCTAssertNil(zeroAmount)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.expenses.isEmpty)
    }

    @MainActor
    func testReceiptItemsShareGroupAndImage() throws {
        let (model, imageStore) = try makeModel()
        let imageName = try imageStore.save(
            UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50)).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            }
        )

        let items = [
            ReceiptDraftItem(title: "牛乳", amount: 198, category: .food),
            ReceiptDraftItem(title: "洗剤", amount: 398, category: .dailyGoods)
        ]
        let count = model.addReceiptItems(
            items,
            merchantName: "スーパーABC",
            date: Date(),
            receiptImageName: imageName
        )

        XCTAssertEqual(count, 2)
        XCTAssertEqual(model.expenses.count, 2)
        XCTAssertEqual(Set(model.expenses.compactMap(\.receiptGroupID)).count, 1)
        XCTAssertTrue(model.expenses.allSatisfy { $0.receiptImageName == imageName })
        XCTAssertTrue(model.expenses.allSatisfy { $0.merchantName == "スーパーABC" })

        let first = model.expenses[0]
        model.deleteExpense(first)
        XCTAssertEqual(model.expenses.count, 1)
        XCTAssertTrue(imageStore.exists(named: imageName), "他の明細が参照している画像は残す")

        model.deleteExpense(model.expenses[0])
        XCTAssertFalse(imageStore.exists(named: imageName), "最後の参照が消えたら画像も削除")
    }

    @MainActor
    func testSameDayMultipleExpensesAndMonthTotal() throws {
        let (model, _) = try makeModel()
        let calendar = KakeiCalendar.calendar
        let base = KakeiCalendar.date(year: 2026, month: 11, day: 20)!

        model.addExpense(title: "朝食", amount: 400, category: .food, date: base)
        model.addExpense(title: "昼食", amount: 900, category: .dining, date: base)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: base)!
        model.addExpense(title: "電車", amount: 210, category: .transport, date: nextDay)

        XCTAssertEqual(model.expenses(on: base).count, 2)
        XCTAssertEqual(model.expenses(on: base).reduce(0) { $0 + $1.amount }, 1300)
        XCTAssertEqual(model.statistics(for: base).total, 1510)
        XCTAssertEqual(model.statistics(for: base).total(on: base), 1300)
    }

    @MainActor
    func testAddReceiptItemsRejectsEmptyInput() throws {
        let (model, _) = try makeModel()
        let count = model.addReceiptItems([], merchantName: nil, date: Date(), receiptImageName: nil)
        XCTAssertEqual(count, 0)
        XCTAssertNotNil(model.errorMessage)
    }
}
