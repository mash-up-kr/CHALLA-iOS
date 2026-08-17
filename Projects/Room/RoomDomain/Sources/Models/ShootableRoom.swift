import Foundation

/// 카메라의 방 선택 목록 한 줄 — `GET /rooms/shootable` 응답 한 줄에 대응한다.
/// 촬영 화면은 제목·남은 장수만 필요해 `Room` 전체가 아니라 이 축약형을 쓴다.
public struct ShootableRoom: Identifiable, Equatable, Sendable {

    /// `Room.id`와 같은 서버 식별자 — 사진 업로드 API가 이 값으로 방을 가리킨다.
    public let id: Room.ID
    public let title: String
    /// 앞으로 찍을 수 있는 장수. 서버가 차감해 내려준다.
    public let remainedPhotoCount: Int
    public let totalPhotoCount: Int

    public init(id: Room.ID, title: String, remainedPhotoCount: Int, totalPhotoCount: Int) {
        self.id = id
        self.title = title
        self.remainedPhotoCount = remainedPhotoCount
        self.totalPhotoCount = totalPhotoCount
    }
}

// MARK: - 프리뷰·데모 샘플

/// id가 음수인 이유는 `Room` 샘플 주석 참고 — 실데이터(양수 id)와 절대 겹치지 않는다.
public extension ShootableRoom {

    static let previewRooms: [ShootableRoom] = [
        ShootableRoom(id: -1, title: "제주 우정 여행", remainedPhotoCount: 6, totalPhotoCount: 24),
        ShootableRoom(id: -2, title: "성수동 필름 산책", remainedPhotoCount: 3, totalPhotoCount: 48),
        ShootableRoom(id: -3, title: "찰나 첫 모임", remainedPhotoCount: 12, totalPhotoCount: 72)
    ]
}
