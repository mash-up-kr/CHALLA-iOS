import Foundation

/// 현재 유효한 액세스 토큰을 공급하는 추상. `CHALLANetwork`가 정의하고, 구현은 `AuthData`가 맡는다.
///
/// 네트워크 모듈은 토큰이 어디에 저장되는지(Keychain 등)를 모른다 —
/// 둘을 잇는 것은 조립 지점의 몫이다 (`docs/ARCHITECTURE.md`의 "토큰 흐름").
public protocol TokenProvider: Sendable {

    /// 현재 액세스 토큰. 비로그인 상태면 `nil`.
    func accessToken() async -> String?
}
