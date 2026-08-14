@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("DTO → RoomCard 매핑")
struct RoomCardMappingTests {

    private static func dto(
        status: RoomStatusDTO = .shooting,
        thumbnails: [String] = [],
        photoPrintCompletedAt: String? = nil,
        createdAt: String = "2026-08-01T10:00:00",
        expiresAt: String = "2026-08-31T10:00:00"
    ) -> RoomListResponseDTO.RoomDTO {
        RoomListResponseDTO.RoomDTO(
            id: 1,
            status: status,
            title: "친구들과 강릉 여행",
            memberCount: 3,
            totalPhotoCount: 24,
            remainedPhotoCount: 10,
            thumbnailImageUrls: thumbnails,
            photoPrintCompletedAt: photoPrintCompletedAt,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    @Test("서버 필드가 카드로 옮겨진다")
    func mapsFields() throws {
        let card = try Self.dto(thumbnails: ["https://img.example.com/1.jpg"]).toDomain()

        #expect(card.id == 1)
        #expect(card.room.title == "친구들과 강릉 여행")
        #expect(card.memberCount == 3)
        #expect(card.room.totalPhotoCount == 24)
        #expect(card.room.remainedPhotoCount == 10)
        #expect(card.room.shotPhotoCount == 14)
        #expect(card.thumbnailURLs.map(\.absoluteString) == ["https://img.example.com/1.jpg"])
        #expect(card.coverImageURL?.absoluteString == "https://img.example.com/1.jpg")
    }

    @Test("서버 상태 표기가 도메인 상태로 1:1 대응된다", arguments: [
        (RoomStatusDTO.shooting, Room.Status.shooting),
        (RoomStatusDTO.printPending, Room.Status.printWaiting),
        (RoomStatusDTO.printCompleted, Room.Status.printed)
    ])
    func mapsStatus(dtoStatus: RoomStatusDTO, domainStatus: Room.Status) throws {
        let card = try Self.dto(status: dtoStatus).toDomain()

        #expect(card.room.status == domainStatus)
    }

    @Test("타임존 명시(Z) 표기도 타임존 없는 표기도 파싱된다", arguments: [
        "2026-08-11T13:46:28.169Z", // 스웨거 견본 형식 (ISO8601 + 소수점 초)
        "2026-08-11T13:46:28Z", //     ISO8601
        "2026-08-11T13:46:28.169", //  타임존 없음 + 소수점 초
        "2026-08-11T13:46:28" //       타임존 없음 (Spring LocalDateTime 기본)
    ])
    func parsesBothDateNotations(dateString: String) throws {
        let card = try Self.dto(createdAt: dateString).toDomain()

        // 표기마다 기준 타임존이 달라 절대값 비교 대신 "파싱에 성공해 카드가 만들어졌는지"를 본다.
        #expect(card.id == 1)
    }

    @Test("필수 날짜가 계약과 다르면 .unknown을 던진다")
    func rejectsMalformedRequiredDate() {
        #expect(throws: RoomError.unknown) {
            _ = try Self.dto(createdAt: "2026/08/01 10:00").toDomain()
        }
    }

    @Test("인화 시각은 형식이 어긋나도 방을 버리지 않고 nil이 된다")
    func toleratesMalformedOptionalDate() throws {
        let card = try Self.dto(status: .printCompleted, photoPrintCompletedAt: "not-a-date").toDomain()

        #expect(card.room.photoPrintCompletedAt == nil)
    }

    @Test("깨진 썸네일 URL은 걸러지고 나머지는 남는다")
    func dropsInvalidThumbnailURL() throws {
        let card = try Self.dto(thumbnails: ["", "https://img.example.com/ok.jpg"]).toDomain()

        #expect(card.thumbnailURLs.map(\.absoluteString) == ["https://img.example.com/ok.jpg"])
    }
}
