import Foundation

struct GitHubDeviceFlowService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func requestDeviceAuthorization(configuration: GitHubAuthConfiguration) async throws -> DeviceAuthorization {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        request.httpBody = "client_id=\(configuration.clientID)".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)

        guard let verificationURI = URL(string: payload.verificationURI) else {
            throw AppError.infrastructure("GitHub 返回了无效的 verification_uri")
        }

        return DeviceAuthorization(
            deviceCode: payload.deviceCode,
            userCode: payload.userCode,
            verificationURI: verificationURI,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            interval: payload.interval
        )
    }

    func exchangeDeviceCode(_ authorization: DeviceAuthorization, configuration: GitHubAuthConfiguration) async throws -> DeviceTokenExchangeResult {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        request.httpBody = [
            "client_id": configuration.clientID,
            "device_code": authorization.deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        .percentEncodedFormData()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let errorPayload = try? JSONDecoder().decode(DeviceTokenErrorResponse.self, from: data) {
            return .pending(errorPayload.error)
        }

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        return .success(payload.tokenBundle)
    }

    func refreshToken(_ refreshToken: String, configuration: GitHubAuthConfiguration) async throws -> TokenBundle {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        request.httpBody = [
            "client_id": configuration.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        .percentEncodedFormData()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let errorPayload = try? JSONDecoder().decode(DeviceTokenErrorResponse.self, from: data) {
            throw AppError.infrastructure("刷新令牌失败：\(errorPayload.error)")
        }

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        return payload.tokenBundle
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppError.infrastructure("GitHub 响应类型无效")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AppError.infrastructure("GitHub 授权请求失败：HTTP \(http.statusCode) \(message)")
        }
    }
}

enum DeviceTokenExchangeResult: Sendable {
    case success(TokenBundle)
    case pending(String)
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct DeviceTokenErrorResponse: Decodable {
    let error: String
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let refreshTokenExpiresIn: Int?
    let tokenType: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case tokenType = "token_type"
    }

    var tokenBundle: TokenBundle {
        TokenBundle(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) },
            refreshTokenExpiresAt: refreshTokenExpiresIn.map { Date().addingTimeInterval(TimeInterval($0)) },
            tokenType: tokenType
        )
    }
}

private extension Dictionary where Key == String, Value == String {
    func percentEncodedFormData() -> Data? {
        map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        .sorted()
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
