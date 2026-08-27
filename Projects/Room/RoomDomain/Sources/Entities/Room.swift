import Foundation

/// 방 그 자체 — 목록(GET /rooms)과 상세(GET /rooms/{id})가 공통으로 주는 필드만 담는다.
/// 한쪽 API만 주는 값(인원수·썸네일·초대 코드)은 화면별 Model(RoomCard·RoomDetail)이
/// 이 타입을 감싸며 들고 있다. 그래야 어느 값이 어느 API에서 오는지 타입에 드러난다.
public struct Room: Identifiable, Equatable, Sendable {

    /// 서버 식별자 (int64). 사진·채팅 API도 같은 타입으로 방을 가리킨다.
    public let id: Int64
    public let title: String
    public let status: Status
    /// 이 방에서 찍기로 한 총 장수. 서버가 정하는 자유값이라 enum이 아니다 —
    /// 24/48/72 중 고르는 것은 만들 때 입력(`RoomDraft.shotCount`)의 규칙이다.
    public let totalPhotoCount: Int
    /// 앞으로 찍을 수 있는 장수. 서버가 차감해 내려준다.
    public let remainedPhotoCount: Int
    public let createdAt: Date
    /// 이 시점이 지나면 서버가 방을 지운다 (30일). 상세 화면의 D-day 재료.
    public let expiresAt: Date
    /// 인화가 완료되는 시각 — 촬영을 마치면 서버가 +24시간으로 정한다 (백엔드 확정 2026-08-13).
    /// 인화 대기 화면의 카운트다운 기준값이며, 촬영 중에는 nil.
    public let photoPrintCompletedAt: Date?

    public enum Status: Equatable, Sendable {
        case shooting // 촬영 중
        case printWaiting // 인화 대기
        case printed // 인화 완료
    }

    /// 지금까지 촬영된 장수. 서버는 남은 장수를 주므로 계산으로 얻는다.
    public var shotPhotoCount: Int {
        totalPhotoCount - remainedPhotoCount
    }

    /// 제목만 바꾼 사본. 필드가 전부 let이라 제목 하나를 고치려면 통째로 다시 만들어야 해서 둔다.
    /// 이름 변경이 서버에 저장된 직후, 재조회가 오기 전 구간에 화면이 새 제목을 먼저 그리는 용도다 —
    /// 설정에서 상세로 돌아갈 때의 조립(App)과 데모 저장소의 변경 반영(RoomData)이 쓴다.
    public func renamed(to title: String) -> Room {
        Room(
            id: id,
            title: title,
            status: status,
            totalPhotoCount: totalPhotoCount,
            remainedPhotoCount: remainedPhotoCount,
            createdAt: createdAt,
            expiresAt: expiresAt,
            photoPrintCompletedAt: photoPrintCompletedAt
        )
    }

    public init(
        id: Int64,
        title: String,
        status: Status,
        totalPhotoCount: Int,
        remainedPhotoCount: Int,
        createdAt: Date,
        expiresAt: Date,
        photoPrintCompletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.totalPhotoCount = totalPhotoCount
        self.remainedPhotoCount = remainedPhotoCount
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.photoPrintCompletedAt = photoPrintCompletedAt
    }
}

// MARK: - 프리뷰·데모 샘플

/// UseCase `previewValue`와 `RoomData` 샘플이 함께 쓰는 상수.
/// `RoomData`에 두면 previewValue가 Domain → Data 역참조를 만들어 Domain이 들고 있는다.
///
/// id는 음수다 — 서버가 양수 id를 주므로 실데이터와 절대 겹치지 않는다.
/// 날짜는 고정 시각이다 — 프리뷰는 언제 열어도 같은 화면을 그려야 한다.
public extension Room {

    /// 프리뷰·샘플·가짜 저장소가 함께 쓰는 만료 간격(30일).
    /// 실제 만료는 서버가 expiresAt으로 내려준다 — 화면 로직에서 이 값으로 계산하지 말 것.
    static let previewLifetime: TimeInterval = 60 * 60 * 24 * 30

    /// 프리뷰·샘플이 쓰는 인화 완료 시각의 오프셋(만든 지 3일 뒤).
    static let previewPrintCompletionOffset: TimeInterval = 60 * 60 * 24 * 3

    /// 프리뷰 공통 기준 시각 (2026-07-13 00:00 UTC 근처의 고정값).
    private static let previewCreatedAt = Date(timeIntervalSince1970: 1_784_000_000)
    private static let previewExpiresAt = previewCreatedAt.addingTimeInterval(previewLifetime)

    static let previewShooting = Room(
        id: -1,
        title: "제주 우정 여행",
        status: .shooting,
        totalPhotoCount: 24,
        remainedPhotoCount: 12,
        createdAt: previewCreatedAt,
        expiresAt: previewExpiresAt
    )

    static let previewPrintWaiting = Room(
        id: -2,
        title: "성수동 필름 산책",
        status: .printWaiting,
        totalPhotoCount: 48,
        remainedPhotoCount: 0,
        createdAt: previewCreatedAt,
        expiresAt: previewExpiresAt,
        // 인화 대기부터는 완료 예정 시각이 항상 있다 — 실서버 모습과 맞춘다.
        photoPrintCompletedAt: previewCreatedAt.addingTimeInterval(previewPrintCompletionOffset)
    )

    static let previewPrinted = Room(
        id: -3,
        title: "찰나 첫 모임",
        status: .printed,
        totalPhotoCount: 72,
        remainedPhotoCount: 0,
        createdAt: previewCreatedAt,
        expiresAt: previewExpiresAt,
        photoPrintCompletedAt: previewCreatedAt.addingTimeInterval(previewPrintCompletionOffset)
    )

    /// 두 섹션이 모두 보이는 화면을 재현한다.
    static let previewRooms: [Room] = [.previewShooting, .previewPrintWaiting, .previewPrinted]
}
