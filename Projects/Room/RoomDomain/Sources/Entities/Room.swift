import Foundation

/// 사람들이 모여 사진을 찍고 인화를 기다리는 방. 이 모듈이 다루는 대상 그 자체다.
///
/// 필드 목록은 서버 스펙이 아니라 시안의 홈 카드 두 종이 요구하는 값 에서 나왔다.
/// 서버 API가 확정되면 필드가 늘 수 있으나, 화면이 쓰지 않는 값은 그때도 넣지 않는다.
/// - 초대 코드를 넣지 않은 이유: 홈 카드에 그려지지 않는다. 방 상세(별도 이슈)에서
///   필요해지면 그때 추가하고, 그전까지는 저장소가 코드→방 매핑을 자체적으로 들고 있다.
/// - 정렬 키를 넣지 않은 이유: 순서를 서버가 정할지 클라이언트가 정렬할지 미확정이라
///   저장소가 준 순서를 그대로 쓴다.
///
/// 모든 필드가 `let`인 것은 의도다 — 방 정보를 바꾸는 일은 서버에 요청해 새 `Room`을
/// 받는 것이지, 손에 든 값을 고치는 것이 아니다.
public struct Room: Identifiable, Equatable, Sendable {

    /// 서버 식별자. 타입(String vs Int)은 API 확정 시 재검토.
    public let id: String
    public let name: String
    public let status: Status
    /// 참여 인원 (카드의 person 아이콘 옆 숫자).
    public let memberCount: Int
    /// 지금까지 촬영된 장수 (CardItem의 카메라 뱃지 / PrintCard의 totalPhotoCount).
    public let photoCount: Int
    /// 이 방에서 찍기로 한 총 장수 (24/48/72).
    public let shotCount: RoomShotCount
    /// 촬영 중 카드의 대표 사진.
    public let coverImageURL: URL?
    /// 촬영 완료 카드의 낱장 썸네일. 앞 4장만 쓰인다.
    public let thumbnailURLs: [URL]

    public enum Status: Equatable, Sendable {
        case shooting       // 촬영 중
        case printWaiting   // 인화 대기
        case printed        // 인화 완료
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
/// `RoomData`에 두면 previewValue가 Domain → Data 역참조를 만들기 때문에 Domain이 들고 있는다.
public extension Room {

    /// 촬영 중 — 사진 URL은 서버가 없어 전부 비워 둔다 (카드는 플레이스홀더를 그린다).
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

    /// 인화 대기 — 촬영을 끝내고 인화를 기다리는 방.
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

    /// 인화 완료.
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

    /// 세 상태가 하나씩 섞인 목록 — 두 섹션이 모두 보이는 화면을 재현한다.
    static let previewRooms: [Room] = [.previewShooting, .previewPrintWaiting, .previewPrinted]
}
