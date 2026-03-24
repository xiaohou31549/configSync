import Foundation

public struct DeviceAuthorization: Equatable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: URL
    public let expiresAt: Date
    public let interval: Int

    public init(
        deviceCode: String,
        userCode: String,
        verificationURI: URL,
        expiresAt: Date,
        interval: Int
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURI = verificationURI
        self.expiresAt = expiresAt
        self.interval = interval
    }
}

public enum GitHubAuthProgress: Equatable, Sendable {
    case requestingCode
    case waitingForUser(DeviceAuthorization)
    case polling(nextInterval: Int)
    case refreshingToken
    case loadingProfile
    case completed(username: String)

    public var message: String {
        switch self {
        case .requestingCode:
            "正在请求 GitHub Device Code"
        case .waitingForUser:
            "请在浏览器完成 GitHub 授权"
        case let .polling(nextInterval):
            "正在轮询授权结果，间隔 \(nextInterval) 秒"
        case .refreshingToken:
            "正在刷新访问令牌"
        case .loadingProfile:
            "正在拉取 GitHub 用户资料"
        case let .completed(username):
            "已登录为 \(username)"
        }
    }
}
