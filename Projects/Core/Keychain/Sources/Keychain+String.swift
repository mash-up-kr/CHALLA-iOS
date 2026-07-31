import Foundation

/// 문자열 값(토큰 등)을 위한 편의 확장. UTF-8로 인코딩해 `Data` API에 위임한다.
public extension Keychain {

    func saveString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try save(data, for: key)
    }

    /// 저장된 데이터가 UTF-8 문자열이 아니면 `KeychainError.dataConversionFailed`.
    func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }
}
