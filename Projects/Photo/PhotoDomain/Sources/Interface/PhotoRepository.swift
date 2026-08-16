import Foundation

/// 사진 API 추상. 구현은 `PhotoData`가 맡는다 (서버 명세 확정 전까지는 Mock만 존재).
/// 구현체는 실패를 `PhotoError`로 정규화해 던져야 한다.
public protocol PhotoRepository: Sendable {

    /// 방의 인화된 사진을 찍힌 순서대로 돌려준다.
    func photos(inRoom roomID: String) async throws -> [Photo]

    /// 리액션을 목표 상태로 맞추고 갱신된 사진을 돌려준다.
    /// 뒤집기가 아니라 멱등 형태인 이유는 재시도·취소가 안전해야 하기 때문이다.
    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool) async throws -> Photo

    /// 원본 이미지 바이트. 사진첩 저장에 쓴다.
    func imageData(for photo: Photo) async throws -> Data
}
