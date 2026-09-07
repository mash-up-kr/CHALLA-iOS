@testable import RoomData
import CHALLANetwork
import Foundation
import RoomDomain
import Testing

@Suite("DefaultRoomRepository — 커버")
struct DefaultRoomRepositoryCoverTests {

    private static let coverJSON = """
    "cover": {
      "coverImageUrl": "https://img.example.com/cover.jpg",
      "sticker": { "id": 3, "imageUrl": "https://img.example.com/s.png",
                   "color": { "id": 2, "name": "라즈베리", "hex": "#FF1887" } }
    }
    """

    private static func listJSON(cover: String?) -> String {
        """
        {
          "success": true, "message": "ok",
          "data": {
            "rooms": [
              {
                "id": 7, "status": "SHOOTING", "title": "제주 우정 여행", "memberCount": 1,
                "totalPhotoCount": 48, "remainedPhotoCount": 48, "thumbnailImageUrls": [],
                "photoPrintCompletedAt": null,
                "createdAt": "2026-08-01T10:00:00", "expiresAt": "2026-08-31T10:00:00"
                \(cover.map { ", " + $0 } ?? "")
              }
            ]
          }
        }
        """
    }

    private static func detailJSON(cover: String?) -> String {
        """
        {
          "success": true, "message": "ok",
          "data": {
            "room": {
              "id": 7, "title": "제주 우정 여행", "status": "SHOOTING",
              "totalPhotoCount": 48, "remainedPhotoCount": 48,
              "invitationCode": "1928121", "photoPrintCompletedAt": null,
              "createdAt": "2026-08-01T10:00:00", "expiresAt": "2026-08-31T10:00:00"
              \(cover.map { ", " + $0 } ?? "")
            }
          }
        }
        """
    }

    private static let optionsJSON = """
    {
      "success": true, "message": "ok",
      "data": {
        "room": {
          "stickers": [
            { "id": 1, "imageUrl": "https://img.example.com/1.png" },
            { "id": 2, "imageUrl": "https://img.example.com/2.png" }
          ],
          "colors": [
            { "id": 1, "name": "레몬에이드", "hex": "#D5F700" },
            { "id": 2, "name": "라즈베리", "hex": "#FF1887" }
          ]
        }
      }
    }
    """

    private static let emptyOKJSON = #"{ "success": true, "message": "ok", "data": null }"#

    @Test("목록: cover가 있으면 카드의 방에 실린다")
    func listMapsCover() async throws {
        let repository = DefaultRoomRepository(client: MockHTTPClient.returning(json: Self.listJSON(cover: Self.coverJSON)))

        let card = try #require(try await repository.rooms().first)

        #expect(card.room.cover.imageURL?.absoluteString == "https://img.example.com/cover.jpg")
        #expect(card.room.cover.sticker?.id == 3)
        #expect(card.room.cover.sticker?.color.hex == "#FF1887")
    }

    @Test("목록: cover가 null이거나 빠져 있어도 빈 커버로 통과한다", arguments: [nil, #""cover": null"#])
    func listToleratesMissingCover(cover: String?) async throws {
        let repository = DefaultRoomRepository(client: MockHTTPClient.returning(json: Self.listJSON(cover: cover)))

        let card = try #require(try await repository.rooms().first)

        #expect(card.room.cover == .none)
    }

    @Test("상세: cover가 방에 실린다")
    func detailMapsCover() async throws {
        let repository = DefaultRoomRepository(client: MockHTTPClient.returning(json: Self.detailJSON(cover: Self.coverJSON)))

        let info = try await repository.roomInfo(id: 7)

        #expect(info.room.cover.sticker?.id == 3)
    }

    @Test("상세: cover가 빠져 있어도 빈 커버로 통과한다")
    func detailToleratesMissingCover() async throws {
        let repository = DefaultRoomRepository(client: MockHTTPClient.returning(json: Self.detailJSON(cover: nil)))

        let info = try await repository.roomInfo(id: 7)

        #expect(info.room.cover == .none)
    }

    @Test("옵션 조회: 경로·bearer를 확인하고 스티커·색이 순서대로 매핑된다")
    func fetchesCoverOptions() async throws {
        let client = MockHTTPClient.returning(json: Self.optionsJSON)
        let repository = DefaultRoomRepository(client: client)

        let options = try await repository.coverOptions()

        #expect(options.stickers.map(\.id) == [1, 2])
        #expect(options.colors.map(\.name) == ["레몬에이드", "라즈베리"])
        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/cover-options")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
    }

    @Test("옵션 조회: success가 false면 서버 메시지를 담아 던진다")
    func coverOptionsUnwrapsFailureEnvelope() async {
        let repository = DefaultRoomRepository(
            client: MockHTTPClient.returning(json: #"{ "success": false, "message": "점검 중입니다.", "data": null }"#)
        )

        await #expect(throws: RoomError.server(message: "점검 중입니다.")) {
            _ = try await repository.coverOptions()
        }
    }

    @Test("커버 수정: 그 방 주소로 PUT을 보내고 세 값을 room 아래에 싣는다")
    func updateCoverSendsBody() async throws {
        let client = MockHTTPClient.returning(json: Self.emptyOKJSON)
        let repository = DefaultRoomRepository(client: client)

        try await repository.updateCover(
            roomID: 7,
            imageURL: URL(string: "https://img.example.com/cover.jpg"),
            stickerID: 3,
            colorID: 2
        )

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/7/cover")
        #expect(request.method == .put)
        #expect(request.usesBearerToken)

        let body = try #require(request.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["room"]?["coverImageUrl"] as? String == "https://img.example.com/cover.jpg")
        #expect(json["room"]?["coverStickerId"] as? Int == 3)
        #expect(json["room"]?["coverStickerColorId"] as? Int == 2)
        #expect(json["room"]?.count == 3)
    }

    @Test("커버 수정: 없애는 값은 키를 남긴 채 null로 보낸다 — 전체 교체 계약")
    func updateCoverEncodesNilsAsNull() async throws {
        let client = MockHTTPClient.returning(json: Self.emptyOKJSON)
        let repository = DefaultRoomRepository(client: client)

        try await repository.updateCover(roomID: 7, imageURL: nil, stickerID: nil, colorID: nil)

        let body = try #require(client.requests.first?.body)
        let text = try #require(String(data: body, encoding: .utf8))
        #expect(text.contains(#""coverImageUrl":null"#))
        #expect(text.contains(#""coverStickerId":null"#))
        #expect(text.contains(#""coverStickerColorId":null"#))
    }

    @Test("커버 수정: success가 false면 서버 메시지를 담아 던진다")
    func updateCoverUnwrapsFailureEnvelope() async {
        let repository = DefaultRoomRepository(
            client: MockHTTPClient.returning(json: #"{ "success": false, "message": "커버를 바꿀 수 없습니다.", "data": null }"#)
        )

        await #expect(throws: RoomError.server(message: "커버를 바꿀 수 없습니다.")) {
            try await repository.updateCover(roomID: 7, imageURL: nil, stickerID: 1, colorID: 1)
        }
    }

    @Test("커버 수정: 전송 실패는 .network로 정규화된다")
    func updateCoverNormalizesTransportError() async {
        let repository = DefaultRoomRepository(
            client: MockHTTPClient.failing(NetworkError.transport(underlying: URLError(.notConnectedToInternet)))
        )

        await #expect(throws: RoomError.network) {
            try await repository.updateCover(roomID: 7, imageURL: nil, stickerID: 1, colorID: 1)
        }
    }
}
