/// 방 하나가 놓일 자리. 상태는 셋인데 화면의 자리는 둘이라, 그 대응을 이 타입이 나타낸다.
///
/// `Room.Status`와 별개 타입인 이유 — 상태는 방의 진행 단계(촬영 중 → 인화 대기 → 인화 완료)이고,
/// 섹션은 그 단계들을 묶는 방식이다. 둘을 한 타입으로 합치면 상태가 늘 때마다 섹션도 함께 늘어난다.
public enum RoomSection: Equatable, Sendable {
    case shooting    // "촬영 중"
    case completed   // "촬영 완료"
}

public extension Room.Status {
    /// 상태 셋을 섹션 둘로 줄인다. 인화 대기와 인화 완료는 촬영이 끝났다는 점에서 같아
    /// 한 섹션에 놓이고, 카드의 칩 문구만 달라진다.
    ///
    /// 이 변환을 한 곳에 모아 두는 이유 — 호출부마다 `status == .printWaiting || status == .printed`로
    /// 쓰면 "둘은 한 묶음"이라는 판단이 코드 곳곳에 흩어진다. 상태가 하나 더 생겼을 때
    /// 고칠 곳이 이 파일 하나로 남게 하려는 것이다.
    var section: RoomSection {
        switch self {
        case .shooting: .shooting
        case .printWaiting, .printed: .completed
        }
    }
}

/// 섞여 있는 방 배열 하나를 받아 화면의 두 자리로 갈라 담아 둔 결과.
///
/// 하는 일은 그게 전부다 — 새 정보를 만들지 않고, 받은 방들을 두 무더기로 나눠 놓는다.
/// 그런데도 타입을 따로 둔 이유가 셋 있다.
///
/// 1. 홈의 화면 4상태(빈 상태 / 촬영 중만 / 촬영 완료만 / 둘 다)를 이 값 하나로 판단한다.
///    두 배열의 비어 있음 조합이 곧 화면 분기라, 뷰가 상태 값을 다시 헤아릴 필요가 없다.
/// 2. 목록을 섹션별로 따로 조회하지 않기 위해서다. 두 번 조회하면 그 사이에 상태가 바뀐 방이
///    양쪽에 나오거나 어디에도 안 나온다. 한 번 받은 결과를 여기서 가르면 그 틈이 없다.
/// 3. 가르는 규칙을 Domain에 묶어 둔다. "인화 대기와 인화 완료를 한 묶음으로 본다"는 판단은
///    홈 화면의 사정이 아니라 방의 성질이라, 방 목록을 쓰는 화면이 늘어도 규칙은 한 벌이다.
///
/// 값을 보관하지 않고 필요할 때마다 새로 만들어 쓴다 (Feature의 `State`에서 computed property로).
/// 방 목록과 이 결과가 어긋날 여지를 두지 않기 위해서다.
///
/// 섹션 안의 순서는 입력 배열의 순서를 그대로 따른다.
public struct RoomBoard: Equatable, Sendable {

    /// 촬영 중 섹션에 놓일 방들.
    public let shooting: [Room]
    /// 촬영 완료 섹션에 놓일 방들 (인화 대기 + 인화 완료).
    public let completed: [Room]

    /// 방 배열 하나를 두 섹션으로 가른다.
    /// - Parameter rooms: 상태가 섞여 있는 방 목록 (`fetchRooms` 결과 그대로).
    public init(rooms: [Room]) {
        shooting = rooms.filter { $0.status.section == .shooting }
        completed = rooms.filter { $0.status.section == .completed }
    }

    /// 두 섹션이 모두 비었는가. 참이면 홈은 목록 대신 빈 상태(인사말 + 진입 버튼 둘)를 그린다.
    public var isEmpty: Bool { shooting.isEmpty && completed.isEmpty }
}
