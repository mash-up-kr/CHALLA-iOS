/// 방이 놓일 자리. 홈 화면의 "촬영 중" · "촬영 완료" 섹션에 대응한다.
public enum RoomSection: Equatable, Sendable {
    case shooting    // "촬영 중"
    case completed   // "촬영 완료"
}

public extension Room.Status {
    /// 상태 셋을 섹션 둘로 줄인다. 인화 대기와 인화 완료는 촬영이 끝났다는 점에서 같아
    /// 한 섹션에 놓이고, 카드의 칩 문구만 달라진다.
    ///
    /// 호출부마다 `status == .printWaiting || status == .printed`로 쓰면 이 판단이 흩어진다.
    var section: RoomSection {
        switch self {
        case .shooting: .shooting
        case .printWaiting, .printed: .completed
        }
    }
}

/// 방 배열 하나를 두 섹션으로 갈라 담은 결과. 홈의 화면 4상태가 두 배열의 비어 있음 조합으로 정해진다.
///
/// 섹션별로 따로 조회하지 않기 위한 타입이다 — 두 번 조회하면 그 사이에 상태가 바뀐 방이
/// 양쪽에 나오거나 어디에도 안 나온다.
public struct RoomBoard: Equatable, Sendable {

    public let shooting: [Room]
    /// 인화 대기 + 인화 완료.
    public let completed: [Room]

    /// 섹션 안의 순서는 입력 배열의 순서를 따른다.
    public init(rooms: [Room]) {
        shooting = rooms.filter { $0.status.section == .shooting }
        completed = rooms.filter { $0.status.section == .completed }
    }

    /// 참이면 홈은 목록 대신 빈 상태를 그린다.
    public var isEmpty: Bool { shooting.isEmpty && completed.isEmpty }
}
