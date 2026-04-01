import Foundation

public enum RepoVisibility: String, CaseIterable, Sendable, Identifiable {
    case all
    case `public`
    case `private`

    public var id: Self { self }
}

public struct Repo: Identifiable, Equatable, Sendable {
    public let id: Int
    public var installationID: Int
    public var name: String
    public var fullName: String
    public var owner: String
    public var visibility: RepoVisibility
    public var defaultBranch: String
    public var archived: Bool

    public init(
        id: Int,
        installationID: Int = 0,
        name: String,
        fullName: String,
        owner: String,
        visibility: RepoVisibility,
        defaultBranch: String,
        archived: Bool
    ) {
        self.id = id
        self.installationID = installationID
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.visibility = visibility
        self.defaultBranch = defaultBranch
        self.archived = archived
    }
}
