import Foundation

/// 支出カテゴリ。rawValue をそのまま保存するため、後から追加・並べ替えても既存データが壊れない。
enum ExpenseCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case food
    case dailyGoods
    case dining
    case transport
    case medical
    case clothing
    case entertainment
    case utilities
    case communication
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "食料品"
        case .dailyGoods: return "日用品"
        case .dining: return "外食"
        case .transport: return "交通費"
        case .medical: return "医療・薬"
        case .clothing: return "衣類"
        case .entertainment: return "娯楽"
        case .utilities: return "光熱費"
        case .communication: return "通信費"
        case .other: return "その他"
        }
    }

    /// SF Symbols 名（iOS 16 で利用可能なもののみ）。
    var symbolName: String {
        switch self {
        case .food: return "cart.fill"
        case .dailyGoods: return "shippingbox.fill"
        case .dining: return "fork.knife"
        case .transport: return "tram.fill"
        case .medical: return "cross.case.fill"
        case .clothing: return "tshirt.fill"
        case .entertainment: return "gamecontroller.fill"
        case .utilities: return "bolt.fill"
        case .communication: return "wifi"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// 保存済みの文字列から安全に復元する。未知の値は「その他」。
    static func stored(_ raw: String?) -> ExpenseCategory {
        guard let raw, let category = ExpenseCategory(rawValue: raw) else { return .other }
        return category
    }
}

/// 1件の支出。Core Data とは分離した値型として扱い、UI とテストをシンプルに保つ。
struct Expense: Identifiable, Equatable, Hashable {
    let id: UUID
    var date: Date
    var title: String
    var amount: Int
    var category: ExpenseCategory
    var memo: String
    var receiptImageName: String?
    var receiptGroupID: UUID?
    var merchantName: String?
    var quantity: Int
    var unitPrice: Int?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        amount: Int,
        category: ExpenseCategory,
        memo: String = "",
        receiptImageName: String? = nil,
        receiptGroupID: UUID? = nil,
        merchantName: String? = nil,
        quantity: Int = 1,
        unitPrice: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = KakeiCalendar.startOfDay(date)
        self.title = title
        self.amount = max(0, amount)
        self.category = category
        self.memo = memo
        self.receiptImageName = receiptImageName
        self.receiptGroupID = receiptGroupID
        self.merchantName = merchantName
        self.quantity = max(1, quantity)
        self.unitPrice = unitPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isFromReceipt: Bool { receiptImageName != nil || receiptGroupID != nil }
}

/// レシート読み取り結果のうち、ユーザーが編集する明細1行分。
struct ReceiptDraftItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var amount: Int
    var category: ExpenseCategory
    var quantity: Int = 1
    var unitPrice: Int?
}

/// OCR 後の解析結果。画像そのものは UI 側で保持する。
struct ParsedReceipt: Equatable {
    var merchantName: String?
    var date: Date?
    var declaredTotal: Int?
    var subtotal: Int?
    var items: [ParsedReceiptItem]
    var rawText: String

    var itemsTotal: Int { items.reduce(0) { $0 + $1.amount } }

    var hasMismatch: Bool {
        guard let declaredTotal, !items.isEmpty else { return false }
        return declaredTotal != itemsTotal
    }

    var difference: Int {
        guard let declaredTotal else { return 0 }
        return declaredTotal - itemsTotal
    }
}

struct ParsedReceiptItem: Equatable {
    var name: String
    var amount: Int
    var quantity: Int
    var unitPrice: Int?
    var category: ExpenseCategory
}
