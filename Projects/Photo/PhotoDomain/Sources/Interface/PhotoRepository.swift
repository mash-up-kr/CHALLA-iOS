import Foundation

/// 사진 API 프로토콜. 구현은 `PhotoData`가 맡는다.
/// 구현은 실패를 `PhotoError`로 바꿔 던져야 한다.
public protocol PhotoRepository: Sendable {

    /// 방의 인화된 사진을 찍힌 순서대로 돌려준다(목록만 — 리액션은 포함하지 않는다).
    /// 서버 목록 API는 `hasNext`와 함께 페이지네이션을 지원한다.
    func photos(inRoom roomID: Int64) async throws -> [Photo]

    /// 사진 한 장의 리액션(스티커 + 유저별 종류 전체)을 상세(`chats`)에서 받아 온다.
    /// 목록엔 리액션이 없어, 사진을 펼칠 때 이 값만 따로 받아 지연 반영한다 — 안 본 사진은 요청하지 않아 1+N을 피한다.
    func reactions(forPhotoID photoID: String) async throws -> PhotoReactions

    /// 사진에 리액션을 남긴다. 리액션 API는 `roomID`도 요구한다(EMOJI 채팅으로 저장).
    ///
    /// 서버가 갱신 사진을 돌려주지 않고 해제 API도 없어, 반환값 없이 성공 여부만 알린다 —
    /// 화면 갱신은 호출부가 낙관적으로 반영하고, 해제(`isOn == false`)는 호출부가 UI에서 막는다.
    func setReaction(roomID: Int64, photoID: String, kind: ReactionKind, isOn: Bool) async throws

    /// 원본 이미지 바이트. 사진첩 저장에 쓴다.
    func imageData(for photo: Photo) async throws -> Data
}
