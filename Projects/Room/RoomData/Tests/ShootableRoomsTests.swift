@testable import RoomData
import CHALLANetwork
import Foundation
import RoomDomain
import Testing

@Suite("DefaultRoomRepository.shootableRooms")
struct ShootableRoomsTests {

    private static let listJSON = """
    {
      "success": true,
      "message": "ok",
      "data": {
        "rooms": [
          { "id": 7, "title": "제주 우정 여행", "remainedPhotoCount": 6, "totalPhotoCount": 24 },
          { "id": 8, "title": "성수동 필름 산책", "remainedPhotoCount": 0, "totalPhotoCount": 48 }
        ]
      }
    }
    """

    @Test("촬영 가능한 방 목록을 순서 그대로 돌려준다")
    func fetchesShootableRooms() async throws {
        let client = MockHTTPClient.returning(json: Self.listJSON)
        let repository = DefaultRoomRepository(client: client)

        let rooms = try await repository.shootableRooms()

        #expect(rooms == [
            ShootableRoom(id: 7, title: "제주 우정 여행", remainedPhotoCount: 6, totalPhotoCount: 24),
            ShootableRoom(id: 8, title: "성수동 필름 산책", remainedPhotoCount: 0, totalPhotoCount: 48)
        ])
        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/shootable")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
    }

    @Test("success가 false면 서버 메시지를 담아 던진다")
    func unwrapsFailureEnvelope() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "점검 중", "data": null }"#
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.server(message: "점검 중")) {
            _ = try await repository.shootableRooms()
        }
    }

    @Test("InMemory 저장소는 촬영 중 상태의 방만 내려준다")
    func inMemoryFiltersShootingRooms() async throws {
        let repository = InMemoryRoomRepository(
            cards: [RoomCard.previewShooting, .previewPrintWaiting, .previewPrinted]
        )

        let rooms = try await repository.shootableRooms()

        #expect(rooms.map(\.id) == [RoomCard.previewShooting.id])
    }
}
