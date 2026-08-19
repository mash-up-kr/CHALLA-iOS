import Foundation
import PhotoDomain
import RoomDomain

/// 데모앱이 화면에 채워 넣는 값들.
///
/// 방 목록 샘플(`RoomSamples`)을 쓰지 않고 따로 두는 이유는 두 가지다 —
/// 상태마다 슬롯 수·찍힌 장수를 다르게 잡아야 하고, 인화 대기는 카운트다운이 돌아야 해서
/// 완료 시각을 실행 시점 기준으로 잡아야 한다 (고정 날짜를 쓰면 0:00:00만 보인다).
enum DemoSamples {

    /// 시안에 적힌 초대 코드. 저장소에 등록해 두면 방 상세가 이 값을 보여준다.
    static let inviteCode = "1928121"

    /// id가 음수인 이유는 `InMemoryRoomRepository.nextID` 주석 참고 — 데모는 -20번대를 쓴다.
    /// 생성·만료일은 화면이 실행할 때마다 달라지지 않도록 고정한다.
    private static let createdAt = Date(timeIntervalSince1970: 1_784_000_000)
    private static let expiresAt = createdAt.addingTimeInterval(Room.previewLifetime)

    /// 인화 완료까지 남은 시간. 타입을 명시해 둔다 —
    /// 리터럴 곱셈을 인자 자리에 그대로 두면 타입 추론이 제한 시간을 넘긴다.
    private static let secondsUntilPrinted: TimeInterval = 2 * 3600 + 59 * 60 + 58

    /// 상태별로 보여줄 방. 슬롯 수(총 촬영 장수)와 남은 장수가 상태마다 다르다.
    static func room(for state: DemoScreen.DetailState) -> Room {
        switch state {
        case .shooting, .invite, .error:
            return shootingRoom(remained: 24)
        case .shootingPartial:
            return shootingRoom(remained: 12)
        case .printWaiting:
            return Room(
                id: -21,
                title: "성수동 필름 산책",
                status: .printWaiting,
                totalPhotoCount: 48,
                remainedPhotoCount: 0,
                createdAt: createdAt,
                expiresAt: expiresAt,
                // 시안 문구("2:59:58 후 인화 완료")와 같은 값에서 시작해 실제로 줄어든다.
                photoPrintCompletedAt: Date.now.addingTimeInterval(secondsUntilPrinted)
            )
        case .printed:
            return Room(
                id: -22,
                title: "인화 완료 된 방이에요",
                status: .printed,
                totalPhotoCount: 72,
                remainedPhotoCount: 0,
                createdAt: createdAt,
                expiresAt: expiresAt,
                photoPrintCompletedAt: createdAt.addingTimeInterval(Room.previewPrintCompletionOffset)
            )
        }
    }

    /// 상태별로 인화된 사진 장수. 그리드는 이 수만큼 채우고 나머지는 빈 슬롯으로 둔다.
    static func photoCount(for state: DemoScreen.DetailState) -> Int {
        switch state {
        case .shooting, .invite, .error: return 0
        case .shootingPartial: return 12
        case .printWaiting, .printed: return room(for: state).totalPhotoCount
        }
    }

    /// 참여자 바에 들어갈 사람들. 마지막 한 명은 닉네임을 정하지 않은 사용자다.
    static let members: [RoomMember] = [
        RoomMember(id: -1, nickname: "나는야멋쟁이토마토", imageURL: avatarURL(seed: "member1")),
        RoomMember(id: -2, nickname: "찰나둥이", imageURL: avatarURL(seed: "member2")),
        RoomMember(id: -3, nickname: "부리부리자에몽", imageURL: avatarURL(seed: "member3")),
        RoomMember(id: -4, nickname: "해피하우스", imageURL: avatarURL(seed: "member4")),
        RoomMember(id: -5, nickname: "사리곰탕면", imageURL: nil),
        RoomMember(id: -6, nickname: nil, imageURL: nil)
    ]

    /// 슬롯에 채울 사진. 사진 6장을 돌려 쓴다 — 슬롯마다 다른 주소를 주면 수십 건이 한꺼번에
    /// 나가 picsum이 막고, 같은 주소는 이미지 로더가 캐시로 재사용한다.
    static func photos(count: Int) -> [Photo] {
        (0 ..< count).compactMap { index in
            guard let url = photoURL(seed: "slot\(index % 6)") else { return nil }
            return Photo(
                id: "\(index)",
                imageURL: url,
                author: PhotoAuthor(id: "-1", nickname: "나는야멋쟁이토마토"),
                capturedAt: createdAt.addingTimeInterval(TimeInterval(index) * 60)
            )
        }
    }

    private static func shootingRoom(remained: Int) -> Room {
        Room(
            id: -20,
            title: "친구들과 강릉 여행",
            status: .shooting,
            totalPhotoCount: 24,
            remainedPhotoCount: remained,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    /// 시드가 같으면 항상 같은 사진이 와서 검수할 때마다 화면이 달라지지 않는다 (RoomSamples와 같은 방식).
    private static func photoURL(seed: String) -> URL? {
        URL(string: "https://picsum.photos/seed/challa-\(seed)/300/400")
    }

    private static func avatarURL(seed: String) -> URL? {
        URL(string: "https://picsum.photos/seed/challa-\(seed)/100")
    }
}
