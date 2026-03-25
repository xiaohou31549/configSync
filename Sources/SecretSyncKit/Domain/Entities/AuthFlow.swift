import Foundation

public struct OAuthAuthorizationContext: Equatable, Sendable {
    public let authorizationURL: URL
    public let redirectURI: String
    public let callbackPath: String
    public let port: Int
    public let state: String
    public let codeVerifier: String

    public init(
        authorizationURL: URL,
        redirectURI: String,
        callbackPath: String,
        port: Int,
        state: String,
        codeVerifier: String
    ) {
        self.authorizationURL = authorizationURL
        self.redirectURI = redirectURI
        self.callbackPath = callbackPath
        self.port = port
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

public struct OAuthCallbackPayload: Equatable, Sendable {
    public let code: String
    public let state: String

    public init(code: String, state: String) {
        self.code = code
        self.state = state
    }
}

public enum GitHubAuthProgress: Equatable, Sendable {
    case preparingBrowserLogin
    case openingBrowser(URL)
    case waitingForBrowserCallback(port: Int)
    case exchangingCode
    case refreshingToken
    case loadingProfile
    case completed(username: String)

    public var message: String {
        switch self {
        case .preparingBrowserLogin:
            "正在准备 GitHub 浏览器授权"
        case .openingBrowser:
            "正在打开 GitHub 授权页"
        case let .waitingForBrowserCallback(port):
            "浏览器已打开，正在等待 GitHub 回调到本地端口 \(port)"
        case .exchangingCode:
            "正在用授权码换取访问令牌"
        case .refreshingToken:
            "正在刷新访问令牌"
        case .loadingProfile:
            "正在拉取 GitHub 用户资料"
        case let .completed(username):
            "已登录为 \(username)"
        }
    }
}
