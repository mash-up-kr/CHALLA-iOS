import Foundation
import RoomDomain

/// 서버 없이 화면을 확인하려고 쓰는 목 데이터. `InMemoryRoomRepository`에  넣는다.
///
/// 목록 셋이 데모앱 `--state`와 짝을 이룬다.
/// - `mixed` → `default` (촬영 중 + 촬영 완료)
/// - `shootingOnly` → `shooting`
/// - `completedOnly` → `printed`
///
/// 사진 URL이 채워져 있다는 것이 Domain의 `Room.previewXxx`와 다른 점이다.
/// 그쪽은 Xcode 프리뷰용이라 네트워크를 타면 안 돼서 비워 뒀다.
/// 인화 카드는 사진이 있어야 낱장이 쌓인 모습과 "+N"이 그려지므로, 검수에는 이쪽이 필요하다.
///
/// TODO: 서버가 붙으면 실앱에는 필요 없다. 데모앱·검수용으로 남길지는 그때 정한다.
public enum RoomSamples {

    /// 시안에 적힌 초대 코드. 이 코드로 `gangneung` 방에 입장한다.
    public static let inviteCode = "1928121"

    /// 촬영 중인 방만 있는 목록.
    public static let shootingOnly: [Room] = [gangneung]

    /// 촬영이 끝난 방만 있는 목록 (인화 대기 + 인화 완료).
    public static let completedOnly: [Room] = [seongsu, firstMeeting]

    /// 두 섹션이 모두 보이는 목록.
    public static let mixed: [Room] = [gangneung, seongsu, firstMeeting]

    /// 초대 코드 → 방 id.
    public static let inviteCodes: [String: Room.ID] = [inviteCode: gangneung.id]

    // MARK: - 방

    private static let gangneung = Room(
        id: "sample-gangneung",
        name: "친구들과 강릉 여행",
        status: .shooting,
        memberCount: 11,
        photoCount: 24,
        shotCount: .twentyFour,
        coverImageURL: photoURL(seed: "gangneung-cover", size: 400),
        thumbnailURLs: []
    )

    private static let seongsu = Room(
        id: "sample-seongsu",
        name: "성수동 필름 산책",
        status: .printWaiting,
        memberCount: 6,
        photoCount: 48,
        shotCount: .fortyEight,
        coverImageURL: photoURL(seed: "seongsu-cover", size: 400),
        thumbnailURLs: thumbnailURLs(prefix: "seongsu")
    )

    private static let firstMeeting = Room(
        id: "sample-first-meeting",
        name: "인화 완료 된 방이에요",
        status: .printed,
        memberCount: 11,
        photoCount: 72,
        shotCount: .seventyTwo,
        coverImageURL: photoURL(seed: "first-meeting-cover", size: 400),
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
