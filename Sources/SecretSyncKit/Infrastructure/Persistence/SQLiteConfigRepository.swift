import Foundation
import SQLite3

public actor SQLiteConfigRepository: ConfigRepository {
    private let databaseURL: URL
    private var database: OpaquePointer?

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL

        let parentDirectory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        var handle: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &handle) == SQLITE_OK else {
            throw Self.databaseError(from: handle, prefix: "打开本地数据库失败")
        }

        try Self.migrate(database: handle)
        self.database = handle
    }

    public static func makeDefault(fileManager: FileManager = .default) throws -> SQLiteConfigRepository {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appending(path: "SecretSync", directoryHint: .isDirectory)
        let databaseURL = directory.appending(path: "config.sqlite3")
        return try SQLiteConfigRepository(databaseURL: databaseURL)
    }

    public func listItems() async throws -> [ConfigItem] {
        let sql = """
        SELECT id, name, type, description, variable_value, created_at, updated_at
        FROM config_items
        ORDER BY updated_at DESC
        """
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        var items: [ConfigItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = try stringValue(at: 0, from: statement)
            let name = try stringValue(at: 1, from: statement)
            let typeRaw = try stringValue(at: 2, from: statement)
            let description = optionalStringValue(at: 3, from: statement)
            let variableValue = optionalStringValue(at: 4, from: statement)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))

            guard let uuid = UUID(uuidString: id) else {
                throw AppError.infrastructure("本地数据库中的配置 ID 无效：\(id)")
            }

            guard let type = ConfigItemType(rawValue: typeRaw) else {
                throw AppError.infrastructure("本地数据库中的配置类型无效：\(typeRaw)")
            }

            let value: String
            switch type {
            case .variable:
                value = variableValue ?? ""
            case .secret:
                value = variableValue ?? ""
            }

            items.append(
                ConfigItem(
                    id: uuid,
                    name: name,
                    type: type,
                    value: value,
                    description: description,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }

        return items
    }

    public func save(draft: ConfigItemDraft) async throws -> ConfigItem {
        let now = Date()
        let id = draft.id ?? UUID()
        let existing = try await item(for: id)
        let createdAt = existing?.createdAt ?? now

        let sql = """
        INSERT INTO config_items (id, name, type, description, variable_value, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            type = excluded.type,
            description = excluded.description,
            variable_value = excluded.variable_value,
            updated_at = excluded.updated_at
        """

        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bind(id.uuidString, at: 1, to: statement)
        try bind(draft.name, at: 2, to: statement)
        try bind(draft.type.rawValue, at: 3, to: statement)
        try bindNullable(draft.description.isEmpty ? nil : draft.description, at: 4, to: statement)

        switch draft.type {
        case .variable:
            try bind(draft.value, at: 5, to: statement)
        case .secret:
            try bind(draft.value, at: 5, to: statement)
        }

        sqlite3_bind_double(statement, 6, createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 7, now.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("保存配置项失败")
        }

        return ConfigItem(
            id: id,
            name: draft.name,
            type: draft.type,
            value: draft.value,
            description: draft.description.isEmpty ? nil : draft.description,
            createdAt: createdAt,
            updatedAt: now
        )
    }

    public func delete(id: UUID) async throws {
        let sql = "DELETE FROM config_items WHERE id = ?"
        let statement = try prepareStatement(sql)
        defer { sqlite3_finalize(statement) }

        try bind(id.uuidString, at: 1, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError("删除配置项失败")
        }

    }

    private func item(for id: UUID) async throws -> ConfigItem? {
        try await listItems().first { $0.id == id }
    }

    private static func migrate(database: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS config_items (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT,
            variable_value TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_config_items_updated_at ON config_items(updated_at DESC);
        """

        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw databaseError(from: database, prefix: "初始化本地数据库结构失败")
        }
    }

    private func prepareStatement(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError("SQL 预编译失败")
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, value, -1, sqliteTransient) == SQLITE_OK else {
            throw databaseError("SQL 参数绑定失败")
        }
    }

    private func bindNullable(_ value: String?, at index: Int32, to statement: OpaquePointer?) throws {
        if let value {
            try bind(value, at: index, to: statement)
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw databaseError("SQL 空值绑定失败")
            }
        }
    }

    private func stringValue(at index: Int32, from statement: OpaquePointer?) throws -> String {
        guard let cString = sqlite3_column_text(statement, index) else {
            throw AppError.infrastructure("本地数据库字段为空，位置 \(index)")
        }
        return String(cString: cString)
    }

    private func optionalStringValue(at index: Int32, from statement: OpaquePointer?) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }
    private func databaseError(_ prefix: String) -> AppError {
        Self.databaseError(from: database, prefix: prefix)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension SQLiteConfigRepository {
    static func databaseError(from database: OpaquePointer?, prefix: String) -> AppError {
        let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "未知 SQLite 错误"
        return .infrastructure("\(prefix)：\(message)")
    }
}
