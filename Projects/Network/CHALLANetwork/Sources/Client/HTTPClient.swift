import Foundation

/// 엔드포인트를 실제로 전송하는 실행기의 추상.
///
/// Data 레이어(Repository 구현)는 이 프로토콜에만 의존하고,
/// 합성 루트가 `DefaultHTTPClient`(실제 구현) 혹은 Mock을 주입한다.
/// `Sendable`이라 TCA `@Dependency` 등 동시성 경계 너머로 안전하게 주입·공유된다.
public protocol HTTPClient: Sendable {

    /// 응답 디코딩용 공용 디코더 — 구현체가 생성 시 한 번 만들어 보관한다.
    var decoder: JSONDecoder { get }

    /// 상태 코드 필터링은 하지 않는다 — 호출부가 `filterSuccessfulStatusCodes()`로 결정한다.
    func request(_ endpoint: some Endpoint) async throws -> Response
}

public extension HTTPClient {

    /// 전송 → 2xx 필터 → `Decodable` 디코딩까지 한 번에 처리하는 편의 메서드.
    ///
    /// ```swift
    /// let rooms = try await client.request(RoomEndpoint.rooms, as: [RoomDTO].self)
    /// ```
    func request<T: Decodable>(
        _ endpoint: some Endpoint,
        as type: T.Type
    ) async throws -> T {
        let response = try await request(endpoint).filterSuccessfulStatusCodes()
        return try response.map(type, using: decoder)
    }
}
