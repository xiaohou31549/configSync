import Testing
@testable import SecretSyncKit
import Foundation

@Test("HarnessRuntime 会从环境变量解析测试模式")
func harnessRuntimeReadsEnvironment() {
    let runtime = HarnessRuntime.current(environment: [
        "SECRET_SYNC_HARNESS": "1",
        "SECRET_SYNC_USE_IN_MEMORY_STORE": "1",
        "SECRET_SYNC_USE_MOCK_SERVICES": "1",
        "SECRET_SYNC_SKIP_SESSION_RESTORE": "1",
        "SECRET_SYNC_AUTH_SETTINGS_DIR": "/tmp/secretsync-auth",
        "SECRET_SYNC_DATABASE_PATH": "/tmp/secretsync.sqlite3",
        "SECRET_SYNC_KEYCHAIN_SERVICE": "com.tough.SecretSync.tests"
    ])

    #expect(runtime.isEnabled)
    #expect(runtime.useInMemoryStore)
    #expect(runtime.useMockServices)
    #expect(runtime.skipSessionRestore)
    #expect(runtime.authSettingsDirectory?.path().hasPrefix("/tmp/secretsync-auth") == true)
    #expect(runtime.databaseURL?.path() == "/tmp/secretsync.sqlite3")
    #expect(runtime.keychainService == "com.tough.SecretSync.tests")
}
