/// 방을 만들기 위해 사용자가 고른 값. 드로어에서 만들어져 `RoomRepository.createRoom`까지 간다.
///
/// `Room`으로 대신할 수 없다 — id·상태·인원수는 서버가 정하는 값이라 만들기 전에는
/// 가짜 값을 지어넣어야 하고, 그러면 만들어진 방과 아직 아닌 방이 타입으로 구분되지 않는다.
/// 커버 이미지 설정(시안 2차)은 여기에 필드를 늘려 흡수한다.
public struct RoomDraft: Equatable, Sendable {

    public let name: String
    public let shotCount: RoomShotCount

    public init(name: String, shotCount: RoomShotCount) {
        self.name = name
        self.shotCount = shotCount
    }
}
