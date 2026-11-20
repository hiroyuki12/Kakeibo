import XCTest

final class KakeiNoteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var saveButton: XCUIElement {
        XCUIApplication().buttons["entry.saveButton"]
    }

    func testManualEntryAppearsInCalendar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_IN_MEMORY"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KAKEINOTE"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["金額"].exists)

        let amountField = app.textFields["entry.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("1280")

        if app.toolbars.buttons["完了"].waitForExistence(timeout: 2) {
            app.toolbars.buttons["完了"].tap()
        }

        let titleField = app.textFields["entry.titleField"]
        titleField.tap()
        titleField.typeText("Lunch")

        if app.toolbars.buttons["完了"].waitForExistence(timeout: 2) {
            app.toolbars.buttons["完了"].tap()
        }

        let save = app.buttons["entry.saveButton"].exists
            ? app.buttons["entry.saveButton"]
            : app.buttons["登録する"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts["Lunch"].waitForExistence(timeout: 5))

        let calendarTab = app.tabBars.buttons["カレンダー"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 5))
        calendarTab.tap()

        XCTAssertTrue(app.staticTexts["カレンダー"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥1,280"].waitForExistence(timeout: 5))
    }

    func testReceiptScanOptionsFromEntryScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_IN_MEMORY"]
        app.launch()

        let scanButton = app.buttons["entry.scanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 15))
        scanButton.tap()

        XCTAssertTrue(app.buttons["写真ライブラリから選択"].waitForExistence(timeout: 5))
    }

    func testReceiptReviewRegistersParsedItems() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_IN_MEMORY", "-UITEST_RECEIPT_REVIEW"]
        app.launch()

        XCTAssertTrue(app.staticTexts["読み取り結果"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.textFields.matching(identifier: "receipt.itemTitle").count, 4)
        XCTAssertTrue(
            app.textFields.matching(NSPredicate(format: "value == %@", "イオンスタイル 渋谷店")).count > 0
        )
        XCTAssertTrue(app.staticTexts["¥1,172"].exists || app.staticTexts["明細合計"].exists)

        // シートが閉じる（＝保存が完了する）まで、保存 → 確認の流れを最大4回試す。
        // シミュレータが高負荷のとき、最初のタップがアプリに届かないことがある。
        var saved = false
        for _ in 0..<4 {
            let mismatchButton = app.buttons["明細合計で登録"]
            if mismatchButton.exists {
                mismatchButton.tap()
            } else if app.buttons["receipt.saveButton"].exists {
                app.buttons["receipt.saveButton"].tap()
            }
            if waitUntilSheetClosedOrAlertVisible(app: app, timeout: 10) {
                saved = true
                break
            }
        }
        XCTAssertTrue(saved, "レシート明細の登録を完了できませんでした")

        // トーストは一時的な表示のため検証対象にせず、安定したUI要素で
        // 登録結果（件数と合計）を確認する。サンプルの日付は「今日」なので
        // 明細は入力画面の「今日の記録」に反映される。
        let todaySummary = app.staticTexts["4件 · ¥1,172"]
        var appeared = todaySummary.waitForExistence(timeout: 10)
        for _ in 0..<3 where !appeared {
            app.swipeUp()
            appeared = todaySummary.exists
        }
        XCTAssertTrue(appeared, "今日の記録に4件・合計¥1,172が反映されていません")
    }

    /// シートが閉じたか、確認アラートが出たかを待つ。
    /// true = シートが閉じた（保存完了）、false = アラートが表示されている。
    private func waitUntilSheetClosedOrAlertVisible(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let sheet = app.staticTexts["読み取り結果"]
        let confirmButton = app.buttons["明細合計で登録"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !sheet.exists { return true }
            if confirmButton.exists { return false }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return !sheet.exists
    }

    /// 実際の SQLite ストアを使い、アプリ再起動後も支出が残ることを確認する。
    func testExpensePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["KAKEINOTE"].waitForExistence(timeout: 20))

        let title = "再起動テスト\(Int(Date().timeIntervalSince1970))"
        let amountField = app.textFields["entry.amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("3210")

        if app.toolbars.buttons["完了"].waitForExistence(timeout: 2) {
            app.toolbars.buttons["完了"].tap()
        }

        let titleField = app.textFields["entry.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        if app.toolbars.buttons["完了"].waitForExistence(timeout: 2) {
            app.toolbars.buttons["完了"].tap()
        }

        let save = app.buttons["entry.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["KAKEINOTE"].waitForExistence(timeout: 20))

        let persisted = app.staticTexts[title]
        for _ in 0..<4 where !persisted.exists {
            app.swipeUp()
        }
        XCTAssertTrue(persisted.waitForExistence(timeout: 5), "再起動後に登録した支出が見つかりません")
        XCTAssertTrue(app.staticTexts["¥3,210"].exists, "再起動後に金額が保持されていません")
    }
}
