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
        XCTAssertTrue(wantCard(app, titled: "UI test headphones").waitForExistence(timeout: 5))
    }

    func testWantSurvivesRelaunch() {
        var app = launch(["-WantWiseResetData"])
        addWant(app, title: "Relaunch test", price: "12", reason: "Testing")
        XCTAssertTrue(wantCard(app, titled: "Relaunch test").waitForExistence(timeout: 5))
        app.terminate()

        app = launch()
        XCTAssertTrue(wantCard(app, titled: "Relaunch test").waitForExistence(timeout: 5))
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

    /// The Milestone 1 loop end to end on the on-disk store (CLOUD_MAC_SESSION.md §6, checks 4–10):
    /// add → list → relaunch → reconsider (wait longer) → decide → decision history → relaunch.
    func testMilestone1AcceptanceLoop() {
        let title = "Acceptance kite"
        var app = launch(["-WantWiseResetData"])
        addWant(app, title: title, price: "25", reason: "Windy days")
        XCTAssertTrue(wantCard(app, titled: title).waitForExistence(timeout: 5))

        app.terminate()
        app = launch()
        XCTAssertTrue(wantCard(app, titled: title).waitForExistence(timeout: 5), "Want lost on relaunch")

        // First reconsideration: wait longer.
        makeOnlyWantReady(app)
        app.buttons["thinkAboutIt"].firstMatch.tap()
        XCTAssertTrue(app.buttons["decision-waitLonger"].waitForExistence(timeout: 5))
        app.buttons["decision-waitLonger"].tap()
        XCTAssertTrue(app.buttons["confirmWaitLonger"].waitForExistence(timeout: 5))
        app.buttons["confirmWaitLonger"].tap()
        XCTAssertTrue(app.buttons["doneAfterDecision"].waitForExistence(timeout: 5))
        app.buttons["doneAfterDecision"].tap()
        XCTAssertTrue(wantCard(app, titled: title).waitForExistence(timeout: 5), "Want should be waiting again")

        // Second reconsideration: decide.
        makeOnlyWantReady(app)
        app.buttons["thinkAboutIt"].firstMatch.tap()
        XCTAssertTrue(app.buttons["decision-stillWant"].waitForExistence(timeout: 5))
        app.buttons["decision-stillWant"].tap()
        XCTAssertTrue(app.buttons["doneAfterDecision"].waitForExistence(timeout: 5))
        app.buttons["doneAfterDecision"].tap()

        assertDecidedWithHistory(app, title: title)

        app.terminate()
        app = launch()
        assertDecidedWithHistory(app, title: title)
    }

    private func makeOnlyWantReady(_ app: XCUIApplication) {
        let debug = app.buttons["debugMenu"]
        XCTAssertTrue(debug.waitForExistence(timeout: 5))
        debug.tap()
        let makeReady = app.buttons["Make one ready to think again"]
        XCTAssertTrue(makeReady.waitForExistence(timeout: 5))
        makeReady.tap()
        XCTAssertTrue(app.buttons["thinkAboutIt"].firstMatch.waitForExistence(timeout: 5))
    }

    private func assertDecidedWithHistory(_ app: XCUIApplication, title: String) {
        app.tabBars.buttons["Decided"].tap()
        let row = wantCard(app, titled: title)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Decided Want missing")
        row.tap()
        XCTAssertTrue(app.staticTexts["Chose to wait longer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Still wanted it"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Timeline"].tap()
        XCTAssertTrue(app.staticTexts["Chose to wait longer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Still wanted it"].exists)
    }

    /// Grid cards combine their children into one accessibility element, so match on the label.
    private func wantCard(_ app: XCUIApplication, titled title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
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

        // A vertical-axis TextField is exposed as a text view.
        let reasonField = app.descendants(matching: .any)["reasonField"]
        reasonField.tap()
        reasonField.typeText(reason)

        app.buttons["saveWant"].tap()
        let done = app.buttons["doneAfterSave"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }
}
