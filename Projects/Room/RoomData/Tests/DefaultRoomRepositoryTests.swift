@testable import RoomData
import CHALLANetwork
import Foundation
import RoomDomain
import Testing

@Suite("DefaultRoomRepository")
struct DefaultRoomRepositoryTests {

    // MARK: - 픽스처

    /// id 7 하나가 든 목록 응답. 생성·입장 재조회 흐름이 이 방을 찾아낸다.
    private static let listJSON = """
    {
      "success": true,
      "message": "ok",
      "data": {
        "rooms": [
          {
            "id": 7,
            "status": "SHOOTING",
            "title": "제주 우정 여행",
            "memberCount": 1,
            "totalPhotoCount": 48,
            "remainedPhotoCount": 48,
            "thumbnailImageUrls": [],
            "photoPrintCompletedAt": null,
            "createdAt": "2026-08-01T10:00:00",
            "expiresAt": "2026-08-31T10:00:00"
          }
        ]
      }
    }
    """

    private static let idJSON = #"{ "success": true, "message": "ok", "data": { "room": { "id": 7 } } }"#

    /// data가 없는 성공 응답 — 확인·이름 변경처럼 성공 여부만 보는 API가 받는다.
    private static let emptyOKJSON = #"{ "success": true, "message": "ok", "data": null }"#

    // MARK: - 조회

    @Test("목록을 받아 카드로 돌려주고, 세 상태를 전부 쿼리로 싣는다")
    func fetchesRoomsWithAllStatuses() async throws {
        let client = MockHTTPClient.returning(json: Self.listJSON)
        let repository = DefaultRoomRepository(client: client)

        let cards = try await repository.rooms()

        #expect(cards.map(\.id) == [7])
        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
        #expect(request.queryItems?.map(\.name) == ["status", "status", "status"])
        #expect(request.queryItems?.compactMap(\.value) == [
            "SHOOTING", "PHOTO_PRINT_PENDING", "PHOTO_PRINT_COMPLETED"
        ])
    }

    @Test("success가 false면 서버 메시지를 담아 던진다")
    func unwrapsFailureEnvelope() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "점검 중입니다.", "data": null }"#
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.server(message: "점검 중입니다.")) {
            _ = try await repository.rooms()
        }
    }

    @Test("전송 실패는 .network로 정규화된다")
    func normalizesTransportError() async {
        let client = MockHTTPClient.failing(NetworkError.transport(underlying: URLError(.notConnectedToInternet)))
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.network) {
            _ = try await repository.rooms()
        }
    }

    // MARK: - 생성

    @Test("생성: 서버 계약대로 본문을 싣고, 재조회한 목록에서 그 id의 카드를 돌려준다")
    func createSendsBodyAndRefetches() async throws {
        let client = MockHTTPClient.succeeding([Self.idJSON, Self.listJSON])
        let repository = DefaultRoomRepository(client: client)

        let card = try await repository.createRoom(RoomDraft(name: "제주 우정 여행", shotCount: .fortyEight))

        #expect(card.id == 7)
        #expect(client.requests.map(\.path) == ["/api/v1/rooms", "/api/v1/rooms"])
        #expect(client.requests.map(\.method) == [.post, .get])

        // 본문 계약: { room: { title, totalPhotoCount } }
        let body = try #require(client.requests.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["room"]?["title"] as? String == "제주 우정 여행")
        #expect(json["room"]?["totalPhotoCount"] as? Int == 48)
    }

    @Test("생성: 재조회 목록에 그 id가 없으면(서버 계약 위반) .unknown을 던진다")
    func createThrowsWhenRefetchMissesID() async {
        let otherRoomList = Self.listJSON.replacingOccurrences(of: #""id": 7"#, with: #""id": 99"#)
        let client = MockHTTPClient.succeeding([Self.idJSON, otherRoomList])
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.unknown) {
            _ = try await repository.createRoom(RoomDraft(name: "찰나", shotCount: .default))
        }
    }

    // MARK: - 방 상세

    @Test("상세: 경로가 방 id를 가리키고, 응답이 방 정보와 초대 코드로 매핑된다")
    func fetchesRoomInfo() async throws {
        let json = """
        {
          "success": true, "message": "ok",
          "data": {
            "room": {
              "id": 7, "title": "제주 우정 여행", "status": "SHOOTING",
              "totalPhotoCount": 48, "remainedPhotoCount": 48,
              "invitationCode": "1928121", "photoPrintCompletedAt": null,
              "createdAt": "2026-08-01T10:00:00", "expiresAt": "2026-08-31T10:00:00"
            }
          }
        }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultRoomRepository(client: client)

        let info = try await repository.roomInfo(id: 7)

        #expect(info.room.id == 7)
        #expect(info.room.title == "제주 우정 여행")
        #expect(info.invitationCode == "1928121")
        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/7")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
    }

    @Test("참여자: 경로가 users를 가리키고, 배열이 도메인 타입으로 매핑된다")
    func fetchesMembers() async throws {
        let json = """
        {
          "success": true, "message": "ok",
          "data": {
            "users": [
              { "id": 3, "nickname": "토마토", "profileImageUrl": "https://img.example.com/p.jpg" },
              { "id": 5, "nickname": null, "profileImageUrl": null }
            ]
          }
        }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultRoomRepository(client: client)

        let members = try await repository.members(roomID: 7)

        #expect(members.map(\.id) == [3, 5])
        #expect(members[0].nickname == "토마토")
        #expect(members[1].nickname == nil)
        #expect(client.requests.first?.path == "/api/v1/rooms/7/users")
    }

    @Test("상세: 404는 .roomNotFound로 정규화된다")
    func roomInfoMaps404ToRoomNotFound() async {
        let client = MockHTTPClient.failing(
            NetworkError.unacceptableStatusCode(
                statusCode: 404,
                response: Response(statusCode: 404, data: Data())
            )
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.roomInfo(id: -999)
        }
    }

    // MARK: - 입장

    @Test("입장: 서버 계약대로 본문을 싣고, 재조회한 목록에서 그 id의 카드를 돌려준다")
    func joinSendsBodyAndRefetches() async throws {
        let client = MockHTTPClient.succeeding([Self.idJSON, Self.listJSON])
        let repository = DefaultRoomRepository(client: client)

        let card = try await repository.joinRoom(inviteCode: "1928121")

        #expect(card.id == 7)
        #expect(client.requests.map(\.path) == ["/api/v1/rooms/join", "/api/v1/rooms"])

        // 본문 계약: { room: { invitationCode } }
        let body = try #require(client.requests.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["room"]?["invitationCode"] as? String == "1928121")
    }

    @Test("입장: 404는 .roomNotFound로 정규화된다 (잠정 매핑)")
    func joinMaps404ToRoomNotFound() async {
        let client = MockHTTPClient.failing(
            NetworkError.unacceptableStatusCode(
                statusCode: 404,
                response: Response(statusCode: 404, data: Data())
            )
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.roomNotFound) {
            _ = try await repository.joinRoom(inviteCode: "0000000")
        }
    }

    @Test("입장: 409는 .roomFull로 정규화된다 (잠정 매핑)")
    func joinMaps409ToRoomFull() async {
        let client = MockHTTPClient.failing(
            NetworkError.unacceptableStatusCode(
                statusCode: 409,
                response: Response(statusCode: 409, data: Data())
            )
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.roomFull) {
            _ = try await repository.joinRoom(inviteCode: "1928121")
        }
    }

    // MARK: - 인화 완료 확인

    @Test("인화 완료 확인: 그 방 주소로 PUT을 보내고, 실어 보낼 본문은 없다")
    func checkPrintCompletionSendsEmptyPut() async throws {
        let client = MockHTTPClient.returning(json: Self.emptyOKJSON)
        let repository = DefaultRoomRepository(client: client)

        try await repository.checkPrintCompletion(roomID: 7)

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/7/photo-print-completion/check")
        #expect(request.method == .put)
        #expect(request.usesBearerToken)
        #expect(request.body == nil) // 대상은 경로가 가리켜 실을 것이 없다
    }

    @Test("인화 완료 확인: success가 false면 서버 메시지를 담아 던진다")
    func checkPrintCompletionUnwrapsFailureEnvelope() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "확인 처리에 실패했습니다.", "data": null }"#
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.server(message: "확인 처리에 실패했습니다.")) {
            try await repository.checkPrintCompletion(roomID: 7)
        }
    }

    @Test("인화 완료 확인: 전송 실패는 .network로 정규화된다")
    func checkPrintCompletionNormalizesTransportError() async {
        let client = MockHTTPClient.failing(
            NetworkError.transport(underlying: URLError(.notConnectedToInternet))
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.network) {
            try await repository.checkPrintCompletion(roomID: 7)
        }
    }

    // MARK: - 이름 변경

    @Test("이름 변경: 그 방 주소로 PUT을 보내고, 본문에는 새 이름만 싣는다")
    func updateTitleSendsBody() async throws {
        let client = MockHTTPClient.returning(json: Self.emptyOKJSON)
        let repository = DefaultRoomRepository(client: client)

        try await repository.updateTitle(roomID: 7, title: "강릉 여행")

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/rooms/7/title")
        #expect(request.method == .put)
        #expect(request.usesBearerToken)

        // 본문 계약: { room: { title } }
        let body = try #require(request.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: Any]])
        #expect(json["room"]?["title"] as? String == "강릉 여행")
        #expect(json["room"]?.count == 1) // title 외의 값이 딸려 나가면 안 된다
    }

    @Test("이름 변경: success가 false면 서버 메시지를 담아 던진다")
    func updateTitleUnwrapsFailureEnvelope() async {
        let client = MockHTTPClient.returning(
            json: #"{ "success": false, "message": "이름을 바꿀 수 없습니다.", "data": null }"#
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.server(message: "이름을 바꿀 수 없습니다.")) {
            try await repository.updateTitle(roomID: 7, title: "강릉 여행")
        }
    }

    @Test("이름 변경: 전송 실패는 .network로 정규화된다")
    func updateTitleNormalizesTransportError() async {
        let client = MockHTTPClient.failing(
            NetworkError.transport(underlying: URLError(.notConnectedToInternet))
        )
        let repository = DefaultRoomRepository(client: client)

        await #expect(throws: RoomError.network) {
            try await repository.updateTitle(roomID: 7, title: "강릉 여행")
        }
    }
}
