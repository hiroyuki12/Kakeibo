import CoreData
import Foundation

/// 値型 `Expense` と Core Data の橋渡し。UI は Core Data を直接触らない。
final class ExpenseRepository {
    private let context: NSManagedObjectContext

    init(stack: CoreDataStack) {
        context = stack.container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func fetchAll() throws -> [Expense] {
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.fetch(request).map(Self.makeExpense)
    }

    func count() throws -> Int {
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        return try context.count(for: request)
    }

    @discardableResult
    func upsert(_ expense: Expense) throws -> Expense {
        let entity = try fetchEntity(id: expense.id) ?? makeEntity()
        apply(expense, to: entity)
        try context.save()
        return expense
    }

    func upsert(_ expenses: [Expense]) throws {
        guard !expenses.isEmpty else { return }
        for expense in expenses {
            let entity = try fetchEntity(id: expense.id) ?? makeEntity()
            apply(expense, to: entity)
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        if let entity = try fetchEntity(id: id) {
            context.delete(entity)
            try context.save()
        }
    }

    func delete(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        request.predicate = NSPredicate(format: "id IN %@", ids)
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    /// テストや初期化用。通常の UI からは呼ばない。
    func deleteAll() throws {
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        for entity in try context.fetch(request) {
            context.delete(entity)
        }
        try context.save()
    }

    private func fetchEntity(id: UUID) throws -> ExpenseEntity? {
        let request = NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func makeEntity() -> ExpenseEntity {
        NSEntityDescription.insertNewObject(forEntityName: "ExpenseEntity", into: context) as! ExpenseEntity
    }

    private func apply(_ expense: Expense, to entity: ExpenseEntity) {
        entity.id = expense.id
        entity.date = KakeiCalendar.startOfDay(expense.date)
        entity.title = expense.title
        entity.amount = Int64(expense.amount)
        entity.category = expense.category.rawValue
        entity.memo = expense.memo
        entity.receiptImageName = expense.receiptImageName
        entity.receiptGroupID = expense.receiptGroupID
        entity.merchantName = expense.merchantName
        entity.quantity = Int64(max(1, expense.quantity))
        entity.unitPrice = Int64(expense.unitPrice ?? 0)
        entity.createdAt = expense.createdAt
        entity.updatedAt = expense.updatedAt
    }

    private static func makeExpense(from entity: ExpenseEntity) -> Expense {
        Expense(
            id: entity.id,
            date: entity.date,
            title: entity.title,
            amount: Int(entity.amount),
            category: ExpenseCategory.stored(entity.category),
            memo: entity.memo ?? "",
            receiptImageName: entity.receiptImageName,
            receiptGroupID: entity.receiptGroupID,
            merchantName: entity.merchantName,
            quantity: Int(entity.quantity),
            unitPrice: entity.unitPrice > 0 ? Int(entity.unitPrice) : nil,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
}
