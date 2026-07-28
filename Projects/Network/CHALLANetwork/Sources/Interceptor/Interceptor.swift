import Foundation

/// 요청/응답 파이프라인에 끼어드는 관심사(인증·로깅 등)를 분리하는 훅.
/// Moya의 `PluginType`에 대응한다.
///
/// - `adapt`   : 전송 직전 `URLRequest`를 가공 (헤더 주입 등).      ← Moya `prepare`
/// - `willSend`: 전송 직전 사이드이펙트 (요청 로깅 등).             ← Moya `willSend`
/// - `didReceive`: 응답/실패 수신 후 사이드이펙트 (응답 로깅 등).   ← Moya `didReceive`
///
/// 모든 메서드에 기본 구현이 있어 필요한 것만 골라 채택하면 된다.
/// `HTTPClient`가 `Sendable`이므로 인터셉터도 `Sendable`이어야 한다.
public protocol Interceptor: Sendable {

    /// 전송 직전 요청을 가공한다. 여러 인터셉터가 있으면 등록 순서대로 연쇄 적용된다.
    /// 토큰 조회처럼 비동기 작업이 필요할 수 있어 `async`로 둔다.
    func adapt(_ request: URLRequest, for endpoint: any Endpoint) async throws -> URLRequest

    /// 전송 직전 호출된다 (요청을 바꾸지는 않는다).
    func willSend(_ request: URLRequest, endpoint: any Endpoint)

    /// 응답(성공/실패)을 받은 직후 호출된다.
    func didReceive(_ result: Result<Response, NetworkError>, endpoint: any Endpoint)
}

public extension Interceptor {
    func adapt(_ request: URLRequest, for _: any Endpoint) async throws -> URLRequest {
        request
    }

    func willSend(_: URLRequest, endpoint _: any Endpoint) {}
    func didReceive(_: Result<Response, NetworkError>, endpoint _: any Endpoint) {}
}
