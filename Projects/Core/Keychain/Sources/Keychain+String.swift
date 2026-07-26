import Foundation

/// 문자열 값(토큰 등)을 위한 편의 확장. UTF-8로 인코딩해 `Data` API에 위임한다.
public extension Keychain {

    /// `string`을 UTF-8 `Data`로 변환해 저장한다. 같은 `key`가 있으면 덮어쓴다.
    func saveString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try save(data, for: key)
    }

    /// `key`의 값을 UTF-8 문자열로 돌려준다. 항목이 없으면 `nil`.
    /// 저장된 데이터가 UTF-8 문자열이 아니면 `KeychainError.dataConversionFailed`.
    func loadString(for key: String) throws -> String? {
        guard let data = try load(for: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }
}
