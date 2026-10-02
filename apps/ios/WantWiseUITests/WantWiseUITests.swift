import XCTest

/// Smoke tests for the Milestone 1 loop. Uses DEBUG launch arguments (see AppEnvironment).
final class WantWiseUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WantWiseNoReminders"] + extra
        app.launch()
        return app
    }

    func testAddWantAppearsOnList() {
        let app = launch(["-WantWiseInMemory"])
        addWant(app, title: "UI test headphones", price: "49", reason: "Mine hurt my ears")
        XCTAssertTrue(app.staticTexts["UI test headphones"].waitForExistence(timeout: 5))
    }

    func testWantSurvivesRelaunch() {
        var app = launch(["-WantWiseResetData"])
        addWant(app, title: "Relaunch test", price: "12", reason: "Testing")
        XCTAssertTrue(app.staticTexts["Relaunch test"].waitForExistence(timeout: 5))
        app.terminate()

        app = launch()
        XCTAssertTrue(app.staticTexts["Relaunch test"].waitForExistence(timeout: 5))
    }

    func testReconsiderReadySampleWant() {
        let app = launch(["-WantWiseInMemory", "-WantWiseSampleData"])
        let think = app.buttons["thinkAboutIt"].firstMatch
        XCTAssertTrue(think.waitForExistence(timeout: 5))
        think.tap()
        let stillWant = app.buttons["decision-stillWant"]
        XCTAssertTrue(stillWant.waitForExistence(timeout: 5))
        stillWant.tap()
        XCTAssertTrue(app.buttons["doneAfterDecision"].waitForExistence(timeout: 5))
        app.buttons["doneAfterDecision"].tap()
    }

    private func addWant(_ app: XCUIApplication, title: String, price: String, reason: String) {
        let add = app.buttons["addWant"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let titleField = app.textFields["titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        let priceField = app.textFields["priceField"]
        priceField.tap()
        priceField.typeText(price)

        let reasonField = app.textFields["reasonField"]
        reasonField.tap()
        reasonField.typeText(reason)

        app.buttons["saveWant"].tap()
        let done = app.buttons["doneAfterSave"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }
}
