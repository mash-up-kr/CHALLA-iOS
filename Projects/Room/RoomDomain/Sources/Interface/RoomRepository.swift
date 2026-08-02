/// 방 데이터를 가져오고 저장하는 창구. 구현은 `RoomData`가 맡고 이 모듈은 그 실체를 모른다.
///
/// 구현체가 지켜야 할 계약:
/// - 실패는 반드시 `RoomError`로 번역해 던진다 (서버 오류를 그대로 올려보내지 않는다).
/// - 입력값 검증은 하지 않아도 된다 — UseCase가 이미 규칙을 적용한 뒤 호출한다.
public protocol RoomRepository: Sendable {

    /// 내가 속한 방 전부. 상태가 섞인 한 배열로 온다.
    func rooms() async throws -> [Room]

    /// id·상태·인원수는 구현체가 채운다.
    func createRoom(_ draft: RoomDraft) async throws -> Room

    /// 코드에 해당하는 방이 없으면 `RoomError.roomNotFound`를 던진다.
    func joinRoom(inviteCode: String) async throws -> Room
}
