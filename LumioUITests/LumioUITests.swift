import XCTest

final class LumioUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testOnboardingFlowExists() throws {
        // Placeholder: onboarding should be visible on first launch
        XCTAssertTrue(app.staticTexts["Lumio"].waitForExistence(timeout: 3))
    }
}
