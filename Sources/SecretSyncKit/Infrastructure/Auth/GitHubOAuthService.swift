import CryptoKit
import Foundation
import Network

struct GitHubOAuthService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func prepareAuthorization(configuration: GitHubAuthConfiguration) throws -> OAuthAuthorizationContext {
        let state = Self.randomURLSafeString(length: 32)
        let codeVerifier = Self.randomURLSafeString(length: 64)
        let codeChallenge = Self.codeChallenge(from: codeVerifier)
        let port = try Self.reserveLoopbackPort()
        let redirectURI = "http://127.0.0.1:\(port)\(configuration.callbackPath)"

        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationURL = components.url else {
            throw AppError.infrastructure("GitHub 授权地址构造失败")
        }

        return OAuthAuthorizationContext(
            authorizationURL: authorizationURL,
            redirectURI: redirectURI,
            callbackPath: configuration.callbackPath,
            port: port,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    func awaitAuthorizationCallback(context: OAuthAuthorizationContext, timeout: TimeInterval = 180) async throws -> OAuthCallbackPayload {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: UInt16(context.port))!)
        listener.newConnectionLimit = 1

        return try await withThrowingTaskGroup(of: OAuthCallbackPayload.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    listener.stateUpdateHandler = { state in
                        if case let .failed(error) = state {
                            continuation.resume(throwing: AppError.infrastructure("本地授权回调监听失败：\(error.localizedDescription)"))
                        }
                    }

                    listener.newConnectionHandler = { connection in
                        connection.start(queue: .global())
                        receiveCallback(
                            on: connection,
                            expectedPath: context.callbackPath,
                            continuation: continuation
                        )
                    }

                    listener.start(queue: .global())
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw AppError.infrastructure("等待 GitHub 浏览器回调超时，请重试")
            }

            defer {
                listener.cancel()
                group.cancelAll()
            }

            guard let result = try await group.next() else {
                throw AppError.infrastructure("GitHub 回调未返回结果")
            }
            return result
        }
    }

    func exchangeCode(
        _ payload: OAuthCallbackPayload,
        context: OAuthAuthorizationContext,
        configuration: GitHubAuthConfiguration
    ) async throws -> TokenBundle {
        guard payload.state == context.state else {
            throw AppError.infrastructure("GitHub 回调 state 校验失败")
        }

        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        request.httpBody = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code": payload.code,
            "redirect_uri": context.redirectURI,
            "state": context.state,
            "code_verifier": context.codeVerifier
        ]
        .percentEncodedFormData()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let errorPayload = try? JSONDecoder().decode(OAuthTokenErrorResponse.self, from: data) {
            throw AppError.infrastructure("GitHub 令牌交换失败：\(errorPayload.error)")
        }

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        return payload.tokenBundle
    }

    func refreshToken(_ refreshToken: String, configuration: GitHubAuthConfiguration) async throws -> TokenBundle {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SecretSync", forHTTPHeaderField: "User-Agent")
        request.httpBody = [
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        .percentEncodedFormData()

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let errorPayload = try? JSONDecoder().decode(OAuthTokenErrorResponse.self, from: data) {
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
            throw AppError.infrastructure("GitHub OAuth 请求失败：HTTP \(http.statusCode) \(message)")
        }
    }

    private static func reserveLoopbackPort() throws -> Int {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw AppError.infrastructure("创建本地回调端口失败")
        }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            throw AppError.infrastructure("绑定本地回调端口失败")
        }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketDescriptor, $0, &length)
            }
        }

        guard nameResult == 0 else {
            throw AppError.infrastructure("读取本地回调端口失败")
        }

        return Int(UInt16(bigEndian: address.sin_port))
    }

    private static func randomURLSafeString(length: Int) -> String {
        let bytes = (0 ..< length).map { _ in UInt8.random(in: 0 ... 255) }
        let data = Data(bytes)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct OAuthTokenErrorResponse: Decodable {
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

private func receiveCallback(
    on connection: NWConnection,
    expectedPath: String,
    continuation: CheckedContinuation<OAuthCallbackPayload, Error>
) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, error in
        defer { connection.cancel() }

        if let error {
            continuation.resume(throwing: AppError.infrastructure("读取本地授权回调失败：\(error.localizedDescription)"))
            return
        }

        guard let data, let requestText = String(data: data, encoding: .utf8) else {
            continuation.resume(throwing: AppError.infrastructure("本地授权回调内容为空"))
            return
        }

        guard let firstLine = requestText.components(separatedBy: "\r\n").first else {
            continuation.resume(throwing: AppError.infrastructure("本地授权回调格式无效"))
            return
        }

        let components = firstLine.split(separator: " ")
        guard components.count >= 2 else {
            continuation.resume(throwing: AppError.infrastructure("本地授权回调请求行无效"))
            return
        }

        let pathWithQuery = String(components[1])
        guard let urlComponents = URLComponents(string: "http://127.0.0.1\(pathWithQuery)") else {
            continuation.resume(throwing: AppError.infrastructure("本地授权回调 URL 无效"))
            return
        }

        guard urlComponents.path == expectedPath else {
            respond(on: connection, body: "Callback path mismatch.")
            continuation.resume(throwing: AppError.infrastructure("GitHub 回调路径与配置不匹配"))
            return
        }

        let queryMap = Dictionary(uniqueKeysWithValues: (urlComponents.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        if let error = queryMap["error"], !error.isEmpty {
            respond(on: connection, body: "GitHub authorization failed. You can close this page.")
            continuation.resume(throwing: AppError.infrastructure("GitHub 授权失败：\(error)"))
            return
        }

        guard let code = queryMap["code"], let state = queryMap["state"], !code.isEmpty, !state.isEmpty else {
            respond(on: connection, body: "GitHub callback missing code or state.")
            continuation.resume(throwing: AppError.infrastructure("GitHub 回调缺少 code 或 state"))
            return
        }

        respond(on: connection, body: "GitHub authorization completed. You can return to SecretSync.")
        continuation.resume(returning: OAuthCallbackPayload(code: code, state: state))
    }
}

private func respond(on connection: NWConnection, body: String) {
    let html = """
    HTTP/1.1 200 OK\r
    Content-Type: text/html; charset=utf-8\r
    Connection: close\r
    \r
    <html><body style="font-family:-apple-system;padding:32px;"><h2>SecretSync</h2><p>\(body)</p></body></html>
    """
    connection.send(content: html.data(using: .utf8), completion: .contentProcessed { _ in })
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
