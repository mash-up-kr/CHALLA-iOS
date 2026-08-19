import Foundation

/// 응답을 보고 같은 요청을 다시 보낼지 결정한다.
///
/// 재시도는 파이프라인 처음으로 되돌아가므로 `Interceptor.adapt`가 다시 돌고,
/// 그 사이 갱신된 토큰이 새 요청에 실린다.
public protocol Retrier: Sendable {

    /// - Parameter attempt: 지금까지 재시도한 횟수 (첫 응답을 판정할 때는 0).
    func shouldRetry(
        _ result: Result<Response, NetworkError>,
        endpoint: any Endpoint,
        attempt: Int
    ) async -> Bool
}
