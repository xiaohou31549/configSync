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
        let importButton = app.buttons["config.importSampleButton"].firstMatch
        XCTAssertTrue(importButton.waitForExistence(timeout: 10))

        importButton.click()
        let importedItem = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "VPS_HOST")).firstMatch
        XCTAssertTrue(importedItem.waitForExistence(timeout: 5))

        app.buttons["新增"].firstMatch.click()

        let nameField = app.textFields["editor.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("HARNESS_SECRET")

        let valueField = app.secureTextFields["editor.secretValueField"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 3))
        valueField.click()
        valueField.typeText("top-secret-value")

        app.buttons["editor.saveButton"].click()
        let savedItem = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "HARNESS_SECRET")).firstMatch
        XCTAssertTrue(savedItem.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Harness 主界面冒烟截图"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
