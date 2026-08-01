import Foundation

/// 키-값 형태의 보안 저장소 인터페이스. 구현은 `KeychainStore`(Security 프레임워크 기반).
///
/// 토큰 등 민감한 값의 저장에 쓴다. Core 레이어라 누구나 import 가능하지만(규칙 4),
/// 실제 사용처는 Data 레이어를 상정한다 (예: `AuthData`의 `KeychainTokenStore`).
///
/// SecItem API가 동기이므로 이 인터페이스도 동기다.
/// async 경계는 상위 레이어가 담당한다 (예: `TokenProvider.accessToken()`).
public protocol Keychain: Sendable {

    /// `data`를 `key`로 저장한다. 같은 `key`의 항목이 이미 있으면 덮어쓴다.
    func save(_ data: Data, for key: String) throws

    /// `key`의 값을 돌려준다. 항목이 없으면 `nil` (오류가 아님).
    func load(for key: String) throws -> Data?

    /// `key`의 항목을 삭제한다. 항목이 없어도 성공으로 간주한다.
    func delete(for key: String) throws
}
