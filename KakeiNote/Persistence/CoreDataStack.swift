import CoreData
import Foundation

/// Core Data エンティティ。モデルはコードで定義しているため .xcdatamodeld は不要。
@objc(ExpenseEntity)
final class ExpenseEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var title: String
    @NSManaged var amount: Int64
    @NSManaged var category: String
    @NSManaged var memo: String?
    @NSManaged var receiptImageName: String?
    @NSManaged var receiptGroupID: UUID?
    @NSManaged var merchantName: String?
    @NSManaged var quantity: Int64
    @NSManaged var unitPrice: Int64
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

enum CoreDataStackError: LocalizedError {
    case storeLoadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .storeLoadFailed(let error):
            return "データの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
}

/// iOS 16 でも使える Core Data スタック。SQLite をアプリの Application Support に保存する。
final class CoreDataStack {
    let container: NSPersistentContainer

    static var defaultStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KakeiNote", isDirectory: true)
            .appendingPathComponent("KakeiNote.sqlite")
    }

    init(inMemory: Bool = false, storeURL: URL? = nil) throws {
        let model = Self.sharedModel
        container = NSPersistentContainer(name: "KakeiNote", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        } else {
            let url = storeURL ?? Self.defaultStoreURL
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let description = NSPersistentStoreDescription(url: url)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            container.persistentStoreDescriptions = [description]
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw CoreDataStackError.storeLoadFailed(loadError)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
    }

    private static let sharedModel = makeModel()

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "ExpenseEntity"
        entity.managedObjectClassName = NSStringFromClass(ExpenseEntity.self)

        func attribute(
            _ name: String,
            type: NSAttributeType,
            optional: Bool = false,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            attribute.defaultValue = defaultValue
            return attribute
        }

        entity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("date", type: .dateAttributeType),
            attribute("title", type: .stringAttributeType),
            attribute("amount", type: .integer64AttributeType, defaultValue: Int64(0)),
            attribute("category", type: .stringAttributeType),
            attribute("memo", type: .stringAttributeType, optional: true),
            attribute("receiptImageName", type: .stringAttributeType, optional: true),
            attribute("receiptGroupID", type: .UUIDAttributeType, optional: true),
            attribute("merchantName", type: .stringAttributeType, optional: true),
            attribute("quantity", type: .integer64AttributeType, defaultValue: Int64(1)),
            attribute("unitPrice", type: .integer64AttributeType, defaultValue: Int64(0)),
            attribute("createdAt", type: .dateAttributeType),
            attribute("updatedAt", type: .dateAttributeType)
        ]
        entity.uniquenessConstraints = [["id"]]
        model.entities = [entity]
        return model
    }
}
