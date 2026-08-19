import Foundation

/// 사진 API 프로토콜. 구현은 `PhotoData`가 맡는다 (현재는 Mock만 있음).
/// 구현은 실패를 `PhotoError`로 바꿔 던져야 한다.
public protocol PhotoRepository: Sendable {

    /// 방의 인화된 사진을 찍힌 순서대로 돌려준다.
    func photos(inRoom roomID: String) async throws -> [Photo]

    /// 리액션을 목표 상태(isOn)로 맞추고 갱신된 사진을 돌려준다.
    /// 토글이 아니라 멱등 형태인 이유: 재시도·취소가 안전해야 해서다.
    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool) async throws -> Photo

    /// 원본 이미지 바이트. 사진첩 저장에 쓴다.
    func imageData(for photo: Photo) async throws -> Data
}
