import XCTest

@MainActor
final class SecretSyncUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment["SECRET_SYNC_HARNESS"] = "1"
        app.launchEnvironment["SECRET_SYNC_USE_IN_MEMORY_STORE"] = "1"
        app.launchEnvironment["SECRET_SYNC_USE_MOCK_SERVICES"] = "1"
        app.launchEnvironment["SECRET_SYNC_SKIP_SESSION_RESTORE"] = "1"
        app.launchEnvironment["SECRET_SYNC_AUTH_SETTINGS_DIR"] = NSTemporaryDirectory()
        app.launchEnvironment["SECRET_SYNC_KEYCHAIN_SERVICE"] = "com.tough.SecretSync.ui-tests.\(UUID().uuidString)"
        app.launch()
    }

    func testCanImportSamplesAndSaveSecret() throws {
        XCTAssertTrue(app.otherElements["root.dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["config.importSampleButton"].waitForExistence(timeout: 3))

        app.buttons["config.importSampleButton"].click()
        XCTAssertTrue(app.staticTexts["VPS_HOST"].waitForExistence(timeout: 5))

        app.buttons["config.newButton"].click()

        let nameField = app.textFields["editor.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("HARNESS_SECRET")

        let valueField = app.secureTextFields["editor.secretValueField"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 3))
        valueField.click()
        valueField.typeText("top-secret-value")

        app.buttons["editor.saveButton"].click()
        XCTAssertTrue(app.staticTexts["HARNESS_SECRET"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Harness 主界面冒烟截图"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
