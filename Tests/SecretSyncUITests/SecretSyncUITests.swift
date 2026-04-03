import XCTest

final class SecretSyncUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        let authSettingsDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SecretSyncUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: authSettingsDirectory, withIntermediateDirectories: true)
        MainActor.assumeIsolated {
            let app = XCUIApplication()
            app.launchEnvironment["SECRET_SYNC_HARNESS"] = "1"
            app.launchEnvironment["SECRET_SYNC_USE_IN_MEMORY_STORE"] = "1"
            app.launchEnvironment["SECRET_SYNC_SKIP_SESSION_RESTORE"] = "1"
            app.launchEnvironment["SECRET_SYNC_AUTH_SETTINGS_DIR"] = authSettingsDirectory.path
            app.launchEnvironment["SECRET_SYNC_KEYCHAIN_SERVICE"] = "com.tough.SecretSync.ui-tests.\(UUID().uuidString)"
            app.launchEnvironment["GITHUB_APP_ID"] = "3241508"
            app.launchEnvironment["GITHUB_APP_CLIENT_ID"] = "Iv23liPcbu7jrAGxIylq"
            app.launchEnvironment["GITHUB_APP_CLIENT_SECRET"] = "ui-test-client-secret"
            app.launchEnvironment["GITHUB_APP_SLUG"] = "secretvarsync"
            app.launchEnvironment["GITHUB_APP_PRIVATE_KEY_PATH"] = "/tmp/secretvarsync-ui-tests.pem"
            app.launchEnvironment["GITHUB_CALLBACK_PATH"] = "/oauth/callback"
            app.launch()
        }
    }

    @MainActor
    func testCanCreateEditAndDeleteLocalSecret() throws {
        let app = XCUIApplication()
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

    @MainActor
    func testCanStartRealGitHubAppAuthorizationFlow() throws {
        let app = XCUIApplication()
        let loginButton = app.buttons["repository.loginButton"].firstMatch
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))

        loginButton.click()

        let waitingMessage = app.staticTexts["等待浏览器完成 GitHub 授权回调…"]
        XCTAssertTrue(waitingMessage.waitForExistence(timeout: 8))

        let authorizationText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Iv23liPcbu7jrAGxIylq")
        ).firstMatch
        XCTAssertTrue(authorizationText.waitForExistence(timeout: 3))

        let callbackText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "redirect_uri=http%3A%2F%2F127.0.0.1")
        ).firstMatch
        XCTAssertTrue(callbackText.waitForExistence(timeout: 3))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "GitHub App 授权链路冒烟截图"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
