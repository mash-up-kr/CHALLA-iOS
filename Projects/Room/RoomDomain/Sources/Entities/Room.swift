import Foundation

/// 서버 스펙이 없어 필드는 시안의 홈 카드 두 종이 요구하는 값만 담는다.
/// 초대 코드는 카드에 그려지지 않고(저장소가 코드→방 매핑을 따로 들고 있다),
/// 정렬 키는 순서를 정하는 주체가 미확정이라 넣지 않았다.
public struct Room: Identifiable, Equatable, Sendable {

    /// 서버 식별자. 타입(String vs Int)은 API 확정 시 재검토.
    public let id: String
    public let name: String
    public let status: Status
    public let memberCount: Int
    /// 지금까지 촬영된 장수.
    public let photoCount: Int
    /// 이 방에서 찍기로 한 총 장수.
    public let shotCount: RoomShotCount
    /// 촬영 중 카드의 대표 사진.
    public let coverImageURL: URL?
    /// 촬영 완료 카드의 낱장 썸네일. 앞 4장만 쓰인다.
    public let thumbnailURLs: [URL]

    public enum Status: Equatable, Sendable {
        case shooting // 촬영 중
        case printWaiting // 인화 대기
        case printed // 인화 완료
    }

    public init(
        id: String,
        name: String,
        status: Status,
        memberCount: Int,
        photoCount: Int,
        shotCount: RoomShotCount,
        coverImageURL: URL?,
        thumbnailURLs: [URL]
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.memberCount = memberCount
        self.photoCount = photoCount
        self.shotCount = shotCount
        self.coverImageURL = coverImageURL
        self.thumbnailURLs = thumbnailURLs
    }
}

// MARK: - 프리뷰·데모 샘플

/// UseCase `previewValue`와 `RoomData` 샘플이 함께 쓰는 상수.
/// `RoomData`에 두면 previewValue가 Domain → Data 역참조를 만들어 Domain이 들고 있는다.
///
/// 사진 URL은 비워 둔다 — 프리뷰는 네트워크 없이 즉시 그려져야 한다 (카드는 플레이스홀더를 그린다).
public extension Room {

    static let previewShooting = Room(
        id: "preview-shooting",
        name: "제주 우정 여행",
        status: .shooting,
        memberCount: 4,
        photoCount: 12,
        shotCount: .twentyFour,
        coverImageURL: nil,
        thumbnailURLs: []
    )

    static let previewPrintWaiting = Room(
        id: "preview-print-waiting",
        name: "성수동 필름 산책",
        status: .printWaiting,
        memberCount: 6,
        photoCount: 48,
        shotCount: .fortyEight,
        coverImageURL: nil,
        thumbnailURLs: []
    )

    static let previewPrinted = Room(
        id: "preview-printed",
        name: "찰나 첫 모임",
        status: .printed,
        memberCount: 8,
        photoCount: 72,
        shotCount: .seventyTwo,
        coverImageURL: nil,
        thumbnailURLs: []
    )

    /// 두 섹션이 모두 보이는 화면을 재현한다.
    static let previewRooms: [Room] = [.previewShooting, .previewPrintWaiting, .previewPrinted]
}
