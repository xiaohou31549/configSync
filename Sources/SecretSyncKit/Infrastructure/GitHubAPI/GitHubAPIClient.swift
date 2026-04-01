import Foundation

public struct GitHubAPIClient: Sendable {
    private let authRepository: GitHubAuthRepository
    private let session: URLSession
    private let decoder = JSONDecoder()

    public init(authRepository: GitHubAuthRepository, session: URLSession = .shared) {
        self.authRepository = authRepository
        self.session = session
    }

    public func fetchRepositories() async throws -> [Repo] {
        let accessToken = try await authRepository.validUserAccessToken()
        let installations = try await authRepository.accessibleInstallations()
        var repositoriesByID: [Int: Repo] = [:]

        for installation in installations {
            let data = try await performUserRequest(
                path: "/user/installations/\(installation.id)/repositories",
                queryItems: [
                    URLQueryItem(name: "per_page", value: "100")
                ],
                accessToken: accessToken
            )
            let payload = try decoder.decode(InstallationRepositoriesResponse.self, from: data)
            for repository in payload.repositories {
                repositoriesByID[repository.id] = repository.domainModel(installationID: installation.id)
            }
        }

        return repositoriesByID.values.sorted { $0.fullName.lowercased() < $1.fullName.lowercased() }
    }

    private func performUserRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String
    ) async throws -> Data {
        var components = URLComponents(string: "https://api.github.com")!
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw AppError.infrastructure("GitHub 仓库列表 URL 构造失败：\(path)")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.infrastructure("GitHub 仓库列表响应无效")
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AppError.infrastructure("拉取仓库失败：HTTP \(http.statusCode) \(message)")
        }

        return data
    }
}

private struct InstallationRepositoriesResponse: Decodable {
    let repositories: [RepositoryResponse]
}

private struct RepositoryResponse: Decodable {
    struct Owner: Decodable {
        let login: String
    }

    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let isPrivate: Bool
    let defaultBranch: String
    let archived: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case archived
    }

    func domainModel(installationID: Int) -> Repo {
        Repo(
            id: id,
            installationID: installationID,
            name: name,
            fullName: fullName,
            owner: owner.login,
            visibility: isPrivate ? .private : .public,
            defaultBranch: defaultBranch,
            archived: archived
        )
    }
}
