import Foundation

public protocol SecretEncryptionService: Sendable {
    func encrypt(_ plaintext: String, publicKey: String) throws -> String
}

public struct PlaceholderSecretEncryptionService: SecretEncryptionService {
    public init() {}

    public func encrypt(_ plaintext: String, publicKey: String) throws -> String {
        guard !plaintext.isEmpty, !publicKey.isEmpty else {
            throw AppError.validation("缺少加密输入")
        }

        return Data(plaintext.utf8).base64EncodedString()
    }
}
