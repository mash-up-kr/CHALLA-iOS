import Foundation

/// 현재 유효한 액세스 토큰을 공급하는 추상. `CHALLANetwork`가 정의하고, 구현은 `AuthData`가 맡는다.
///
/// 네트워크 모듈은 토큰이 어디에 저장되는지(Keychain 등)를 모른다 —
/// `AuthData`가 이 프로토콜을 구현해 Keychain에서 토큰을 읽어주고,
/// DIContainer가 둘을 연결한다 (아키텍처 문서의 "토큰 흐름" 참고).
/// 테스트 시에는 가짜 `TokenProvider`만 주입하면 된다.
public protocol TokenProvider: Sendable {

    /// 현재 액세스 토큰. 비로그인 상태면 `nil`.
    func accessToken() async -> String?
}
