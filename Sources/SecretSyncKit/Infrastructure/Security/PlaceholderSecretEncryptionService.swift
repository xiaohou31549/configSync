import Foundation
@preconcurrency import Sodium

public protocol SecretEncryptionService: Sendable {
    func encrypt(_ plaintext: String, publicKey: String) throws -> String
}

public struct PlaceholderSecretEncryptionService: SecretEncryptionService {
    public init() {}

    public func encrypt(_ plaintext: String, publicKey: String) throws -> String {
        guard !plaintext.isEmpty, !publicKey.isEmpty else {
            throw AppError.validation("缺少加密输入")
        }

        let sodium = Sodium()

        guard let publicKeyBytes = sodium.utils.base642bin(publicKey, variant: .ORIGINAL) else {
            throw AppError.infrastructure("GitHub 仓库公钥不是有效的 Base64")
        }

        guard let encrypted = sodium.box.seal(message: Array(plaintext.utf8), recipientPublicKey: publicKeyBytes) else {
            throw AppError.infrastructure("使用 libsodium sealed box 加密 Secret 失败")
        }

        guard let encoded = sodium.utils.bin2base64(encrypted, variant: .ORIGINAL) else {
            throw AppError.infrastructure("密文 Base64 编码失败")
        }

        return encoded
    }
}
