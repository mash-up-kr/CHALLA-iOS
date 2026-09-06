import Foundation

/// 사진 API 프로토콜. 구현은 `PhotoData`가 맡는다.
/// 구현은 실패를 `PhotoError`로 바꿔 던져야 한다.
public protocol PhotoRepository: Sendable {

    /// 방의 전체 사진을 촬영 순으로 반환한다. 리액션은 포함하지 않는다.
    func photos(inRoom roomID: Int64) async throws -> [Photo]

    /// 사진의 리액션 목록과 사용자별 이모지 종류를 조회한다. 방 ID가 필요하다.
    func reactions(inRoom roomID: Int64, photoID: String) async throws -> PhotoReactions

    /// 리액션을 생성하고 삭제에 필요한 채팅 ID를 반환한다.
    /// 성공 응답에도 채팅 ID가 없을 수 있다.
    @discardableResult
    func setReaction(roomID: Int64, photoID: String, kind: ReactionKind) async throws -> Int64?

    /// 리액션(EMOJI 채팅) 한 건을 삭제한다.
    func deleteReaction(chatID: Int64) async throws

    /// 원본 이미지 바이트. 사진첩 저장에 쓴다.
    func imageData(for photo: Photo) async throws -> Data

    /// 원본 이미지 데이터를 입력 순서대로 반환한다.
    /// 개별 실패는 결과에 포함하고 나머지 다운로드는 계속한다.
    func imageDataStream(for photos: [Photo]) -> AsyncStream<Result<Data, PhotoError>>
}
