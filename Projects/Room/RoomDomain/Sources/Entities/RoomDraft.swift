/// 방을 만들기 위해 사용자가 고른 값. 드로어에서 만들어져 `RoomRepository.createRoom`까지 간다.
///
/// `Room`을 그대로 쓰지 않는 이유 — id·상태·인원수·촬영 장수는 서버가 정하는 값이라
/// 만들기 전에는 채울 수 없다. `Room`으로 넘기려면 그 자리에 가짜 값을 지어내야 하고,
/// 그러면 "만들어진 방"과 "아직 안 만들어진 방"을 타입으로 구분할 수 없게 된다.
///
/// 커버 이미지 설정(시안 2차)이 추가되면 이 타입에 필드를 늘린다 — 저장소·UseCase의
/// 시그니처는 그대로 둔 채 확장하기 위한 구조다.
public struct RoomDraft: Equatable, Sendable {

    public let name: String
    public let shotCount: RoomShotCount

    public init(name: String, shotCount: RoomShotCount) {
        self.name = name
        self.shotCount = shotCount
    }
}
