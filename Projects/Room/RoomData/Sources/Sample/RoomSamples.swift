import Foundation
import RoomDomain

/// 서버 없이 화면을 확인하려고 쓰는 목 데이터. `InMemoryRoomRepository`에 넣는다.
///
/// 목록 셋이 데모앱 `--state`와 짝을 이룬다.
/// - `mixed` → `default` (촬영 중 + 촬영 완료)
/// - `shootingOnly` → `shooting`
/// - `completedOnly` → `printed`
///
/// 사진 URL이 채워져 있다는 것이 Domain의 `RoomCard.previewXxx`와 다른 점이다.
/// 그쪽은 Xcode 프리뷰용이라 네트워크를 타면 안 돼서 비워 뒀다.
/// 인화 카드는 사진이 있어야 낱장이 쌓인 모습과 "+N"이 그려지므로, 검수에는 이쪽이 필요하다.
public enum RoomSamples {

    /// 시안에 적힌 초대 코드. 이 코드로 `gangneung` 방에 입장한다.
    public static let inviteCode = "1928121"

    /// 촬영 중인 방만 있는 목록.
    public static let shootingOnly: [RoomCard] = [gangneung]

    // 나열 순서는 서버 정렬 합의를 흉내 낸다 — 인화 완료 → 촬영 가능 → 인화 대기(남은 시간 짧은 순).
    // 클라는 재정렬 없이 이 순서 그대로 그리므로, 데모도 같은 순서여야 실화면과 같은 모습이 나온다.

    /// 촬영이 끝난 방만 있는 목록 (인화 완료 + 인화 대기).
    public static let completedOnly: [RoomCard] = [firstMeeting, happyHouse, seongsu]

    /// 두 섹션이 모두 보이는 목록.
    public static let mixed: [RoomCard] = [firstMeeting, happyHouse, gangneung, seongsu]

    /// 초대 코드 → 방 id.
    public static let inviteCodes: [String: Room.ID] = [inviteCode: gangneung.id]

    /// 확인하기를 이미 누른 방 — 데모 홈의 하단 "인화 완료" 목록이 처음부터 채워져 보이게 한다.
    /// (firstMeeting은 하단에, happyHouse는 상단 확인하기 카드로 남는다.)
    public static let checkedPrintedRoomIDs: Set<Room.ID> = [firstMeeting.id]

    // MARK: - 방

    /// id가 음수인 이유는 `InMemoryRoomRepository.nextID` 주석 참고 — 샘플은 -10번대를 쓴다.
    /// 날짜가 고정값인 이유 — 검수할 때마다 화면(D-day 등)이 달라지지 않아야 한다.
    private static let createdAt = Date(timeIntervalSince1970: 1_784_000_000)
    private static let expiresAt = createdAt.addingTimeInterval(Room.previewLifetime)

    private static let gangneung = RoomCard(
        room: Room(
            id: -10,
            title: "친구들과 강릉 여행",
            status: .shooting,
            totalPhotoCount: 24,
            remainedPhotoCount: 1, // 뱃지 23/24
            createdAt: createdAt,
            expiresAt: expiresAt
        ),
        memberCount: 11,
        // 촬영 중 카드의 대표 사진 = 첫 썸네일 (RoomCard.coverImageURL).
        thumbnailURLs: [photoURL(seed: "gangneung-cover", size: 400)].compactMap(\.self)
    )

    private static let seongsu = RoomCard(
        room: Room(
            id: -11,
            title: "성수동 필름 산책",
            status: .printWaiting,
            totalPhotoCount: 48,
            remainedPhotoCount: 0,
            createdAt: createdAt,
            expiresAt: expiresAt,
            // 고정값 원칙의 예외 — 카운트다운은 미래 시각이어야 줄어드는 모습을 검수할 수 있다.
            // 시작값은 시안 숫자(2:15:32)라 실행할 때마다 같은 화면에서 출발한다.
            photoPrintCompletedAt: Date().addingTimeInterval(2 * 60 * 60 + 15 * 60 + 32)
        ),
        memberCount: 6,
        thumbnailURLs: thumbnailURLs(prefix: "seongsu")
    )

    private static let happyHouse = RoomCard(
        room: Room(
            id: -13,
            title: "해피하우스 강",
            status: .printed,
            totalPhotoCount: 24,
            remainedPhotoCount: 0,
            createdAt: createdAt,
            expiresAt: expiresAt,
            photoPrintCompletedAt: createdAt.addingTimeInterval(Room.previewPrintCompletionOffset)
        ),
        memberCount: 11,
        thumbnailURLs: thumbnailURLs(prefix: "happy-house")
    )

    private static let firstMeeting = RoomCard(
        room: Room(
            id: -12,
            title: "인화 완료 된 방이에요",
            status: .printed,
            totalPhotoCount: 72,
            remainedPhotoCount: 0,
            createdAt: createdAt,
            expiresAt: expiresAt,
            photoPrintCompletedAt: createdAt.addingTimeInterval(Room.previewPrintCompletionOffset)
        ),
        memberCount: 11,
        thumbnailURLs: thumbnailURLs(prefix: "first-meeting")
    )

    // MARK: - 사진 URL

    /// 시드가 같으면 항상 같은 사진이 와서 검수할 때마다 화면이 달라지지 않는다
    /// (`CHALLADesignSystemApp`의 갤러리도 같은 방식을 쓴다).
    private static func photoURL(seed: String, size: Int) -> URL? {
        URL(string: "https://picsum.photos/seed/\(seed)/\(size)")
    }

    /// 인화 카드의 낱장 슬롯이 네 칸이라 네 장을 채운다.
    private static func thumbnailURLs(prefix: String) -> [URL] {
        (1 ... 4).compactMap { photoURL(seed: "\(prefix)-\($0)", size: 200) }
    }
}
