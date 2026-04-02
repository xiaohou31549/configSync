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

    func testCanCreateEditAndDeleteLocalSecret() throws {
        let createButton = app.buttons["新建空白 Secret"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.click()

        let nameField = app.textFields["editor.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("HARNESS_SECRET")

        let valueField = app.textFields["editor.valueField"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 3))
        valueField.click()
        valueField.typeText("top-secret-value")

        app.buttons["保存"].firstMatch.click()
        let savedItem = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "HARNESS_SECRET")).firstMatch
        XCTAssertTrue(savedItem.waitForExistence(timeout: 5))

        savedItem.click()
        nameField.click()
        app.typeKey("a", modifierFlags: [.command])
        app.typeText("HARNESS_SECRET_V2")

        let editedValueField = app.textFields["editor.valueField"]
        XCTAssertTrue(editedValueField.waitForExistence(timeout: 3))
        editedValueField.click()
        app.typeKey("a", modifierFlags: [.command])
        app.typeText("top-secret-value-v2")

        app.buttons["保存"].firstMatch.click()
        let updatedItem = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "HARNESS_SECRET_V2")).firstMatch
        XCTAssertTrue(updatedItem.waitForExistence(timeout: 5))

        updatedItem.click()
        app.buttons["删除"].firstMatch.click()
        XCTAssertFalse(updatedItem.waitForExistence(timeout: 2))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Harness 主界面冒烟截图"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
