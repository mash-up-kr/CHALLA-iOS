import Foundation
import RoomDomain

extension RoomDetailResponseDTO.Payload {

    /// 상세 응답 → 방 정보와 초대 코드. 필수 날짜 파싱 실패는 목록 매핑과 같은 정책으로 실패 처리한다.
    /// 요청 id를 함께 받는 이유 — 서버 스키마상 이 응답의 id가 nullable이라, 없으면 요청 id로 채운다.
    func toDomain(requestedID: Room.ID) throws -> (room: Room, invitationCode: String) {
        guard let createdAt = ServerDate.parse(createdAt),
              let expiresAt = ServerDate.parse(expiresAt)
        else {
            throw RoomError.unknown
        }

        let room = Room(
            id: id ?? requestedID,
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
