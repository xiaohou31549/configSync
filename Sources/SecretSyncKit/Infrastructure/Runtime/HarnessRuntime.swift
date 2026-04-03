import Foundation

public struct HarnessRuntime: Sendable {
    public let isEnabled: Bool
    public let useInMemoryStore: Bool
    public let skipSessionRestore: Bool
    public let authSettingsDirectory: URL?
    public let databaseURL: URL?
    public let keychainService: String

    public init(
        isEnabled: Bool,
        useInMemoryStore: Bool,
        skipSessionRestore: Bool,
        authSettingsDirectory: URL?,
        databaseURL: URL?,
        keychainService: String
    ) {
        self.isEnabled = isEnabled
        self.useInMemoryStore = useInMemoryStore
        self.skipSessionRestore = skipSessionRestore
        self.authSettingsDirectory = authSettingsDirectory
        self.databaseURL = databaseURL
        self.keychainService = keychainService
    }

    public static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> HarnessRuntime {
        let isEnabled = environment.flagValue(for: "SECRET_SYNC_HARNESS")
        let useInMemoryStore = environment.flagValue(for: "SECRET_SYNC_USE_IN_MEMORY_STORE", defaultValue: isEnabled)
        let skipSessionRestore = environment.flagValue(for: "SECRET_SYNC_SKIP_SESSION_RESTORE", defaultValue: isEnabled)
        let authSettingsDirectory = environment["SECRET_SYNC_AUTH_SETTINGS_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let databaseURL = environment["SECRET_SYNC_DATABASE_PATH"].map { URL(fileURLWithPath: $0) }
        let keychainService = environment["SECRET_SYNC_KEYCHAIN_SERVICE"] ?? (isEnabled ? "com.tough.SecretSync.harness" : "com.tough.SecretSync")

        return HarnessRuntime(
            isEnabled: isEnabled,
            useInMemoryStore: useInMemoryStore,
            skipSessionRestore: skipSessionRestore,
            authSettingsDirectory: authSettingsDirectory,
            databaseURL: databaseURL,
            keychainService: keychainService
        )
    }
}

private extension Dictionary where Key == String, Value == String {
    func flagValue(for key: String, defaultValue: Bool = false) -> Bool {
        guard let raw = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return defaultValue
        }

        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}
