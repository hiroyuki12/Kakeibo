import XCTest

/// スクリーンショット取得専用の UI テスト。`-UITEST_SEED` でサンプルデータを入れて各画面を撮影する。
final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_IN_MEMORY", "-UITEST_SEED"]
        app.launch()

        XCTAssertTrue(app.staticTexts["KAKEINOTE"].waitForExistence(timeout: 20))
        sleep(1)
        attach(name: "01-entry")

        let calendarTab = app.tabBars.buttons["カレンダー"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 5))
        calendarTab.tap()
        XCTAssertTrue(app.staticTexts["カレンダー"].waitForExistence(timeout: 5))
        sleep(1)
        attach(name: "02-calendar")

        // 支出のある日を選択
        let dayCell = app.buttons.matching(NSPredicate(format: "label CONTAINS '支出 ¥'")).firstMatch
        if dayCell.exists {
            dayCell.tap()
            sleep(1)
            attach(name: "03-calendar-day")
        }

        // 追加シート
        let addButton = app.buttons["calendar.addButton"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            sleep(1)
            attach(name: "04-editor")

            let cancel = app.buttons["キャンセル"].firstMatch
            if cancel.waitForExistence(timeout: 3) {
                cancel.tap()
            } else {
                app.swipeDown()
            }
        }

        _ = calendarTab
    }

    func testCaptureReceiptReview() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITEST_IN_MEMORY", "-UITEST_RECEIPT_REVIEW"]
        app.launch()

        XCTAssertTrue(app.staticTexts["読み取り結果"].waitForExistence(timeout: 20))
        sleep(1)
        attach(name: "05-receipt-review")

        let save = app.buttons["receipt.saveButton"]
        if save.exists {
            save.tap()
            if app.buttons["明細合計で登録"].waitForExistence(timeout: 3) {
                app.buttons["明細合計で登録"].tap()
            }
            sleep(1)
            attach(name: "06-after-receipt-save")
        }
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
