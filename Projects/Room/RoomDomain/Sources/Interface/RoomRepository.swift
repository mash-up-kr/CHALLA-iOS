/// 방 데이터를 가져오고 저장하는 창구. 구현은 `RoomData`가 맡고 이 모듈은 그 실체를 모른다.
///
/// 구현체가 지켜야 할 계약:
/// - 실패는 반드시 `RoomError`로 번역해 던진다 (서버 오류를 그대로 올려보내지 않는다).
/// - 입력값 검증은 하지 않아도 된다 — UseCase가 이미 규칙을 적용한 뒤 호출한다.
public protocol RoomRepository: Sendable {

    /// 내가 속한 방 전부. 상태가 섞인 한 배열로 온다.
    func rooms() async throws -> [RoomCard]

    /// 촬영 가능한 방 목록 — 카메라의 방 선택 드로어가 쓴다.
    func shootableRooms() async throws -> [ShootableRoom]

    /// 만든 방을 홈 목록에 바로 꽂을 수 있는 카드로 돌려준다.
    /// 서버 생성 응답이 id뿐이어도 카드를 채우는 것은 구현체 몫이다 —
    /// 서버 사정이 이 계약까지 올라오지 않게 한다.
    func createRoom(_ draft: RoomDraft) async throws -> RoomCard

    /// 코드에 해당하는 방이 없으면 `RoomError.roomNotFound`를 던진다.
    func joinRoom(inviteCode: String) async throws -> RoomCard

    /// 방 하나의 정보와 초대 코드 (`GET /rooms/{id}`). 없는 방이면 `RoomError.roomNotFound`를 던진다.
    func roomInfo(id: Room.ID) async throws -> (room: Room, invitationCode: String)

    /// 참여자 목록 (`GET /rooms/{id}/users`). 참여한 순서대로 돌려준다.
    func members(roomID: Room.ID) async throws -> [RoomMember]

    /// 인화 완료를 확인했다고 서버에 알린다 (`PUT /rooms/{id}/photo-print-completion/check`).
    /// 응답에 돌려줄 것이 없고, 이후 목록 조회부터 `photoPrintCompletionCheckedAt`이 채워진다.
    func checkPrintCompletion(roomID: Room.ID) async throws
}
