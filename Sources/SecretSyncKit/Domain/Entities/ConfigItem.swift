import Foundation

public enum ConfigItemType: String, CaseIterable, Codable, Sendable, Identifiable {
    case secret
    case variable

    public var id: Self { self }
    public var displayName: String {
        switch self {
        case .secret: "Secret"
        case .variable: "Variable"
        }
    }
}

public struct ConfigItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var type: ConfigItemType
    public var value: String
    public var description: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: ConfigItemType,
        value: String,
        description: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ConfigItemDraft: Equatable, Sendable {
    public var id: UUID?
    public var name: String
    public var type: ConfigItemType
    public var value: String
    public var description: String

    public init(
        id: UUID? = nil,
        name: String = "",
        type: ConfigItemType = .secret,
        value: String = "",
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.description = description
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !value.isEmpty
    }
}
