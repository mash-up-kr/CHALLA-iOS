/// 방을 만들 때 사용자가 고른 값. 방 만들기 드로어가 채워 `CreateRoomUseCase`에 넘긴다.
///
/// `Room`으로 대신하지 않는다 — id·상태·인원수는 서버가 정하는 값이라 만들기 전에는 채울 수 없고,
/// 임의로 채워 넘기면 이미 만든 방과 아직 만들지 않은 방을 구분할 수 없다.
///
/// 커버 이미지 설정(시안 2차)이 붙으면 여기에 필드를 더한다.
public struct RoomDraft: Equatable, Sendable {

    public let name: String
    public let shotCount: RoomShotCount

    public init(name: String, shotCount: RoomShotCount) {
        self.name = name
        self.shotCount = shotCount
    }
}
