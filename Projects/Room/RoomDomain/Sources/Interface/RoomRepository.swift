/// 방 데이터를 어디선가 가져오고 저장하는 창구. 이 모듈은 그 "어디선가"를 알지 않는다.
///
/// Domain이 인터페이스만 갖고 구현을 `RoomData`에 두는 이유 — 서버가 REST든 GraphQL이든,
/// 지금처럼 메모리든, 방을 다루는 규칙은 바뀌지 않아야 한다. 그 경계선이 이 프로토콜이다.
///
/// 구현체가 지켜야 할 계약:
/// - 실패는 반드시 `RoomError`로 번역해 던진다 (서버 오류를 그대로 올려보내지 않는다).
/// - 입력값 검증은 하지 않아도 된다 — UseCase가 이미 규칙을 적용한 뒤 호출한다.
public protocol RoomRepository: Sendable {

    /// 내가 속한 방 전부. 촬영 중·인화 대기·인화 완료가 한 배열로 온다.
    func rooms() async throws -> [Room]

    /// 방을 만들고 만들어진 방을 돌려준다. id·상태·인원수는 구현체가 채운다.
    func createRoom(_ draft: RoomDraft) async throws -> Room

    /// 초대 코드로 방에 입장하고 그 방을 돌려준다.
    /// 코드에 해당하는 방이 없으면 `RoomError.roomNotFound`를 던진다.
    func joinRoom(inviteCode: String) async throws -> Room
}
