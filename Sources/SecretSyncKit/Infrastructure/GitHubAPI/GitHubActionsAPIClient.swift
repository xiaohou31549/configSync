import Foundation

public struct GitHubActionsAPIClient: Sendable {
    private let authRepository: GitHubAuthRepository
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let apiVersion = "2022-11-28"

    public init(authRepository: GitHubAuthRepository, session: URLSession = .shared) {
        self.authRepository = authRepository
        self.session = session
    }

    public func fetchRepositoryPublicKey(owner: String, repo: String, installationID: Int) async throws -> RepositoryPublicKey {
        let data = try await performRequest(
            path: "/repos/\(owner)/\(repo)/actions/secrets/public-key",
            method: "GET",
            installationID: installationID
        )
        return try decoder.decode(RepositoryPublicKey.self, from: data)
    }

    public func upsertRepositorySecret(
        owner: String,
        repo: String,
        installationID: Int,
        name: String,
        encryptedValue: String,
        keyID: String
    ) async throws {
        let payload = RepositorySecretUpsertPayload(encryptedValue: encryptedValue, keyID: keyID)
        _ = try await performRequest(
            path: "/repos/\(owner)/\(repo)/actions/secrets/\(name)",
            method: "PUT",
            installationID: installationID,
            body: try JSONEncoder().encode(payload),
            allowedStatusCodes: [201, 204]
        )
    }

    public func upsertRepositoryVariable(
        owner: String,
        repo: String,
        installationID: Int,
        name: String,
        value: String
    ) async throws {
        let payload = RepositoryVariablePayload(name: name, value: value)
        let encoded = try JSONEncoder().encode(payload)

        do {
            _ = try await performRequest(
                path: "/repos/\(owner)/\(repo)/actions/variables/\(name)",
                method: "PATCH",
                installationID: installationID,
                body: encoded,
                allowedStatusCodes: [204]
            )
        } catch let error as GitHubAPIError where error.statusCode == 404 {
            _ = try await performRequest(
                path: "/repos/\(owner)/\(repo)/actions/variables",
                method: "POST",
                installationID: installationID,
                body: encoded,
                allowedStatusCodes: [201]
            )
        }
    }

    @discardableResult
    private func performRequest(
        path: String,
        method: String,
        installationID: Int?,
        body: Data? = nil,
        allowedStatusCodes: Set<Int> = [200]
    ) async throws -> Data {
        let accessToken = try await authRepository.validInstallationAccessToken(for: installationID)
        var components = URLComponents(string: "https://api.github.com")!
        components.path = path

        guard let url = components.url else {
            throw AppError.infrastructure("GitHub API URL 构造失败：\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.infrastructure("GitHub API 响应无效")
        }

        guard allowedStatusCodes.contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw GitHubAPIError(statusCode: http.statusCode, message: message)
        }

        return data
    }
}

public struct RepositoryPublicKey: Decodable, Sendable {
    public let keyID: String
    public let key: String

    private enum CodingKeys: String, CodingKey {
        case keyID = "key_id"
        case key
    }
}

struct GitHubAPIError: Error, Sendable {
    let statusCode: Int
    let message: String
}

private struct RepositorySecretUpsertPayload: Encodable {
    let encryptedValue: String
    let keyID: String

    private enum CodingKeys: String, CodingKey {
        case encryptedValue = "encrypted_value"
        case keyID = "key_id"
    }
}

private struct RepositoryVariablePayload: Encodable {
    let name: String
    let value: String
}
