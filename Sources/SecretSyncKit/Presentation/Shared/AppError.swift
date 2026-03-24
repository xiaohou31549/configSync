import Foundation

public enum AppError: LocalizedError, Sendable {
    case validation(String)
    case infrastructure(String)

    public var errorDescription: String? {
        switch self {
        case let .validation(message), let .infrastructure(message):
            message
        }
    }
}
