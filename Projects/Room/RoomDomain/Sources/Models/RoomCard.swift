import Foundation

/// 홈 목록 한 칸 — `GET /rooms` 응답 한 줄에 대응한다.
/// 인원수·썸네일은 목록 API만 주는 값이라 `Room`이 아니라 여기에 있다.
public struct RoomCard: Identifiable, Equatable, Sendable {

    public let room: Room
    public let memberCount: Int
    /// 촬영 완료 카드의 낱장 썸네일. 앞 4장만 그려진다.
    public let thumbnailURLs: [URL]
    /// 내가 인화 완료를 확인한 시각. 완료 상태가 아니거나 확인 전이면 nil.
    /// 상세 응답에는 없고 목록 응답에만 있는 값이라, 두 API 공통 필드만 담는 `Room` 대신 여기에 둔다.
    public let photoPrintCompletionCheckedAt: Date?

    /// 방과 카드가 같은 id를 쓴다 — 목록에서 카드를 탭하면 이 id로 방을 가리킨다.
    public var id: Room.ID {
        room.id
    }

    /// 촬영 중 카드의 대표 사진. 서버에 별도 필드가 없어 첫 썸네일을 쓴다.
    /// TODO: 백엔드 확인 — 대표 이미지 = thumbnailImageUrls.first가 맞는지.
    public var coverImageURL: URL? {
        thumbnailURLs.first
    }

    /// 확인 여부 — 확인 시각(날짜)을 화면 배치에 필요한 예/아니오로 줄인 것.
    /// `RoomBoard`가 이 값으로 상단(확인하기 카드)/하단(인화 완료 목록)을 가른다.
    public var isPrintCompletionChecked: Bool {
        photoPrintCompletionCheckedAt != nil
    }

    public init(
        room: Room,
        memberCount: Int,
        thumbnailURLs: [URL],
        photoPrintCompletionCheckedAt: Date? = nil
    ) {
        self.room = room
        self.memberCount = memberCount
        self.thumbnailURLs = thumbnailURLs
        self.photoPrintCompletionCheckedAt = photoPrintCompletionCheckedAt
    }
}

// MARK: - 프리뷰·데모 샘플

/// 썸네일이 비어 있는 이유는 `Room.previewShooting` 주석 참고 — 프리뷰는 네트워크 없이 즉시 그려진다.
public extension RoomCard {

    static let previewShooting = RoomCard(room: .previewShooting, memberCount: 4, thumbnailURLs: [])
    static let previewPrintWaiting = RoomCard(room: .previewPrintWaiting, memberCount: 6, thumbnailURLs: [])
    static let previewPrinted = RoomCard(room: .previewPrinted, memberCount: 8, thumbnailURLs: [])

    /// 두 섹션이 모두 보이는 화면을 재현한다.
    static let previewCards: [RoomCard] = [.previewShooting, .previewPrintWaiting, .previewPrinted]
}
