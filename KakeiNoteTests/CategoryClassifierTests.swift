import XCTest
@testable import KakeiNote

final class CategoryClassifierTests: XCTestCase {
    private let classifier = CategoryClassifier.default

    func testFoodKeywords() {
        XCTAssertEqual(classifier.category(for: "牛乳 1L"), .food)
        XCTAssertEqual(classifier.category(for: "たまご 10個"), .food)
        XCTAssertEqual(classifier.category(for: "トマト"), .food)
        XCTAssertEqual(classifier.category(for: "鶏むね肉"), .food)
        XCTAssertEqual(classifier.category(for: "食パン"), .food)
        XCTAssertEqual(classifier.category(for: "ヨーグルト"), .food)
    }

    func testDailyGoodsKeywords() {
        XCTAssertEqual(classifier.category(for: "洗剤 詰替"), .dailyGoods)
        XCTAssertEqual(classifier.category(for: "ティッシュ 5箱"), .dailyGoods)
        XCTAssertEqual(classifier.category(for: "トイレットペーパー"), .dailyGoods)
        XCTAssertEqual(classifier.category(for: "シャンプー"), .dailyGoods)
        XCTAssertEqual(classifier.category(for: "ゴミ袋"), .dailyGoods)
    }

    func testMedicalKeywords() {
        XCTAssertEqual(classifier.category(for: "マスク 50枚"), .medical)
        XCTAssertEqual(classifier.category(for: "風邪薬"), .medical)
        XCTAssertEqual(classifier.category(for: "絆創膏"), .medical)
    }

    func testOtherCategories() {
        XCTAssertEqual(classifier.category(for: "電車 運賃"), .transport)
        XCTAssertEqual(classifier.category(for: "ガソリン"), .transport)
        XCTAssertEqual(classifier.category(for: "Tシャツ"), .clothing)
        XCTAssertEqual(classifier.category(for: "映画チケット"), .entertainment)
        XCTAssertEqual(classifier.category(for: "電気料金"), .utilities)
        XCTAssertEqual(classifier.category(for: "携帯電話料金"), .communication)
        XCTAssertEqual(classifier.category(for: "ラーメン"), .dining)
        XCTAssertEqual(classifier.category(for: "寿司"), .dining)
    }

    func testUnknownFallsBackToOther() {
        XCTAssertEqual(classifier.category(for: "謎の商品XYZ"), .other)
    }

    func testMerchantFallback() {
        XCTAssertEqual(classifier.category(for: "セットA", merchantName: "スターバックス 渋谷店"), .dining)
        XCTAssertEqual(classifier.category(for: "おにぎり", merchantName: "セブン-イレブン"), .food)
        XCTAssertEqual(classifier.category(for: "処方箋", merchantName: "みどり薬局"), .medical)
    }

    func testKeywordHasPriorityOverMerchantFallback() {
        XCTAssertEqual(classifier.category(for: "洗剤", merchantName: "スターバックス"), .dailyGoods)
    }

    func testCustomRulesCanBePrepended() {
        let custom = CategoryClassifier.default.adding(rules: [
            CategoryRule(category: .entertainment, keywords: ["謎の商品"])
        ])
        XCTAssertEqual(custom.category(for: "謎の商品XYZ"), .entertainment)
        // 元の分類器は影響を受けない
        XCTAssertEqual(classifier.category(for: "謎の商品XYZ"), .other)
    }

    func testAllCategoriesHaveJapaneseNamesAndSymbols() {
        for category in ExpenseCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.symbolName.isEmpty)
        }
        XCTAssertEqual(ExpenseCategory.stored("unknown"), .other)
        XCTAssertEqual(ExpenseCategory.stored(nil), .other)
        XCTAssertEqual(ExpenseCategory.stored("food"), .food)
    }
}
