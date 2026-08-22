import Foundation

/// 페이로드가 없는(무시하는) 응답용 (logout·토큰 해제 등 — `ensureSuccess()`와 함께 쓴다).
public struct EmptyResponseDTO: Decodable, Sendable {
    public init() {}
}
