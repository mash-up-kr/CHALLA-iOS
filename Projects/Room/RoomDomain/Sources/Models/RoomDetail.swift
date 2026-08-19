import Foundation

/// 방 상세 화면 하나를 위한 Model — `Room` + 상세 API만 주는 값.
/// 목록 화면이 쓰는 값(인원수·썸네일)은 `RoomCard`에 있다 — 어느 값이 어느 API에서 오는지 타입에 드러난다.
public struct RoomDetail: Identifiable, Equatable, Sendable {

    public let room: Room
    /// 초대 코드. 상세(`GET /rooms/{id}`)만 준다 — 목록 카드에 실리면 안 되는 값이기도 하다.
    public let invitationCode: String
    /// 참여자 목록 (`GET /rooms/{id}/users`). 두 API 응답을 합치는 것은 UseCase 몫이다.
    public let members: [RoomMember]

    /// 방과 상세가 같은 id를 쓴다.
    public var id: Room.ID {
        room.id
    }

    public init(room: Room, invitationCode: String, members: [RoomMember]) {
        self.room = room
        self.invitationCode = invitationCode
        self.members = members
    }
}

// MARK: - 프리뷰·데모 샘플

public extension RoomDetail {

    static let preview = RoomDetail(
        room: .previewShooting,
        invitationCode: "1928121", // 시안에 적힌 코드 (RoomSamples와 같은 값)
        members: [
            RoomMember(id: -1, nickname: "나는야멋쟁이토마토", imageURL: nil),
            RoomMember(id: -2, nickname: "찰나둥이", imageURL: nil),
            RoomMember(id: -3, nickname: nil, imageURL: nil) // 프로필 미설정 사용자
        ]
    )
}
