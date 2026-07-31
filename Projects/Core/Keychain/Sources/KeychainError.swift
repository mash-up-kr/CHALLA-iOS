import Foundation

/// Keychain 계층에서 발생 가능한 오류.
///
/// Data 레이어는 이 오류를 잡아 도메인 오류로 정규화한다 (예: `AuthError.unknown`).
public enum KeychainError: Error, Equatable, Sendable {

    /// `SecItem*` 호출 실패. 원인 판별용 `OSStatus`를 담는다.
    case unexpectedStatus(OSStatus)

    /// String ↔ Data 변환 실패 (UTF-8로 표현할 수 없는 값 등).
    case dataConversionFailed
}
