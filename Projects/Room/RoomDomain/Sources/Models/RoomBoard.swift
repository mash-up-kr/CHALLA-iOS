/// 카드 배열 하나를 홈의 두 목록으로 갈라 담은 결과.
///
/// 인화 완료 방은 확인 여부에 따라 한쪽에만 놓인다 — 겹치지 않는다.
/// - 상단 가로 스크롤(`active`): 촬영 중·인화 대기 방 전부 + 아직 확인하지 않은 인화 완료 방.
///   확인 전까지 "확인하기" 카드로 상단에 머문다.
/// - 하단 "인화 완료" 목록(`printed`): 확인을 마친 인화 완료 방.
///   (시안의 "촬영 완료만 있을 때" 프레임 — 상단 카드 없이 하단 목록만 있는 화면 — 이 이 상태다.)
///
/// 순서는 두 목록 모두 입력 배열을 그대로 따른다 — 정렬 규칙(완료 → 촬영 가능 → 대기
/// 남은 시간 짧은 순)은 서버가 구현하기로 합의했다 (2026-08-23 백엔드 합의).
///
/// 확인 여부는 서버 응답에 없어 호출부가 로컬 기록을 넘긴다. 섹션별로 따로 조회하지 않는
/// 이유는 기존과 같다 — 두 번 조회하면 그 사이에 상태가 바뀐 방이 양쪽에 나오거나 어디에도 안 나온다.
public struct RoomBoard: Equatable, Sendable {

    /// 상단 가로 스크롤 카드들 (촬영 중 · 인화 대기 · 미확인 인화 완료).
    public let active: [RoomCard]
    /// 하단 "인화 완료" 목록 (확인을 마친 인화 완료 방).
    public let printed: [RoomCard]

    /// - Parameters:
    ///   - cards: 서버가 내려준 순서 그대로의 방 목록.
    ///   - checkedPrintedRoomIDs: 사용자가 확인하기를 누른 인화 완료 방 id 모음.
    ///     서버에 대응 필드가 없어 로컬 기록을 받는다 (기기 간 동기화 안 됨 — 서버 필드 요청 검토).
    public init(cards: [RoomCard], checkedPrintedRoomIDs: Set<Room.ID> = []) {
        active = cards.filter { card in
            card.room.status != .printed || !checkedPrintedRoomIDs.contains(card.room.id)
        }
        printed = cards.filter { card in
            card.room.status == .printed && checkedPrintedRoomIDs.contains(card.room.id)
        }
    }

    /// 참이면 홈은 목록 대신 빈 상태를 그린다.
    public var isEmpty: Bool {
        active.isEmpty && printed.isEmpty
    }
}
