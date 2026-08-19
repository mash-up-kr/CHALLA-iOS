import Foundation
import RoomDomain

extension RoomDetailResponseDTO.Payload {

    /// 상세 응답 → 방 정보와 초대 코드. 필수 날짜 파싱 실패는 목록 매핑과 같은 정책으로 실패 처리한다.
    func toDomain() throws -> (room: Room, invitationCode: String) {
        guard let createdAt = ServerDate.parse(createdAt),
              let expiresAt = ServerDate.parse(expiresAt)
        else {
            throw RoomError.unknown
        }

        let room = Room(
            id: id,
            title: title,
            status: status.toDomain,
            totalPhotoCount: totalPhotoCount,
            remainedPhotoCount: remainedPhotoCount,
            createdAt: createdAt,
            expiresAt: expiresAt,
            photoPrintCompletedAt: photoPrintCompletedAt.flatMap(ServerDate.parse)
        )
        return (room: room, invitationCode: invitationCode)
    }
}

extension RoomMembersResponseDTO.MemberDTO {

    func toDomain() -> RoomMember {
        RoomMember(
            id: id,
            nickname: nickname,
            imageURL: profileImageUrl.flatMap(URL.init(string:))
        )
    }
}
