@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("상세·참여자 DTO 매핑")
struct RoomDetailMappingTests {

    private static func dto(
        createdAt: String = "2026-08-01T10:00:00",
        cover: RoomCoverDTO? = nil
    ) -> RoomDetailResponseDTO.Payload {
        RoomDetailResponseDTO.Payload(
            id: 7,
            title: "제주 우정 여행",
            status: .shooting,
            totalPhotoCount: 24,
            remainedPhotoCount: 12,
            invitationCode: "1928121",
            photoPrintCompletedAt: nil,
            createdAt: createdAt,
            expiresAt: "2026-08-31T10:00:00",
            cover: cover
        )
    }

    @Test("응답의 필드가 방 정보와 초대 코드로 옮겨진다")
    func mapsRoomInfo() throws {
        let (room, code) = try Self.dto().toDomain()

        #expect(room.id == 7)
        #expect(code == "1928121")
    }

    @Test("커버 유무가 방에 반영된다 — 목록 매핑과 같은 정책")
    func mapsCover() throws {
        let sticker = StickerDTO(id: 1, imageUrl: "https://img.example.com/s.png", color: ColorDTO(id: 1, name: "레몬에이드", hex: "#D5F700"))

        let (withCover, _) = try Self.dto(cover: RoomCoverDTO(coverImageUrl: nil, sticker: sticker)).toDomain()
        let (withoutCover, _) = try Self.dto(cover: nil).toDomain()

        #expect(withCover.cover.imageURL == nil)
        #expect(withCover.cover.sticker?.id == 1)
        #expect(withoutCover.cover == .none)
    }

    @Test("필수 날짜가 계약과 다르면 .unknown을 던진다 — 목록 매핑과 같은 정책")
    func rejectsMalformedRequiredDate() {
        #expect(throws: RoomError.unknown) {
            _ = try Self.dto(createdAt: "2026/08/01 10:00").toDomain()
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
