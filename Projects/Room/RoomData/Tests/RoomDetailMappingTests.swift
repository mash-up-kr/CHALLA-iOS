@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("상세·참여자 DTO 매핑")
struct RoomDetailMappingTests {

    private static func dto(
        id: Int64? = 7,
        createdAt: String = "2026-08-01T10:00:00"
    ) -> RoomDetailResponseDTO.Payload {
        RoomDetailResponseDTO.Payload(
            id: id,
            title: "제주 우정 여행",
            status: .shooting,
            totalPhotoCount: 24,
            remainedPhotoCount: 12,
            invitationCode: "1928121",
            photoPrintCompletedAt: nil,
            createdAt: createdAt,
            expiresAt: "2026-08-31T10:00:00"
        )
    }

    @Test("서버가 id를 주면 그 값을 쓴다")
    func usesServerID() throws {
        let (room, code) = try Self.dto(id: 7).toDomain(requestedID: 99)

        #expect(room.id == 7)
        #expect(code == "1928121")
    }

    @Test("서버가 id를 비우면 요청 id로 메꾼다")
    func fallsBackToRequestedID() throws {
        let (room, _) = try Self.dto(id: nil).toDomain(requestedID: 99)

        #expect(room.id == 99)
    }

    @Test("필수 날짜가 계약과 다르면 .unknown을 던진다 — 목록 매핑과 같은 정책")
    func rejectsMalformedRequiredDate() {
        #expect(throws: RoomError.unknown) {
            _ = try Self.dto(createdAt: "2026/08/01 10:00").toDomain(requestedID: 7)
        }
    }

    @Test("참여자 매핑 — 닉네임 nil은 통과하고 깨진 프로필 URL은 버린다")
    func mapsMember() {
        let named = RoomMembersResponseDTO.MemberDTO(
            id: 3, nickname: "토마토", profileImageUrl: "https://img.example.com/p.jpg"
        )
        let anonymous = RoomMembersResponseDTO.MemberDTO(id: 5, nickname: nil, profileImageUrl: "")

        let first = named.toDomain()
        let second = anonymous.toDomain()

        #expect(first.id == 3)
        #expect(first.nickname == "토마토")
        #expect(first.imageURL?.absoluteString == "https://img.example.com/p.jpg")
        #expect(second.nickname == nil)
        #expect(second.imageURL == nil)
    }
}
