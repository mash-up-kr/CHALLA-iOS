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

    /// 촬영이 끝난 방만 있는 목록 (인화 대기 + 인화 완료).
    public static let completedOnly: [RoomCard] = [seongsu, firstMeeting]

    /// 두 섹션이 모두 보이는 목록.
    public static let mixed: [RoomCard] = [gangneung, seongsu, firstMeeting]

    /// 초대 코드 → 방 id.
    public static let inviteCodes: [String: Room.ID] = [inviteCode: gangneung.id]

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
            remainedPhotoCount: 0, // 24장을 다 찍은 촬영 중 방 (기존 샘플 수치 유지)
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
            expiresAt: expiresAt
        ),
        memberCount: 6,
        thumbnailURLs: thumbnailURLs(prefix: "seongsu")
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
