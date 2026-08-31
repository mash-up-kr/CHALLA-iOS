@testable import PhotoData
import CHALLANetwork
import Foundation
import PhotoDomain
import Testing

@Suite("DefaultPhotoRepository")
struct DefaultPhotoRepositoryTests {

    // MARK: - 목록 조회

    @Test("목록을 도메인 Photo로 변환하고 roomId·page·size 쿼리를 싣는다")
    func mapsListWithQuery() async throws {
        let json = """
        {
          "success": true, "message": "ok",
          "data": {
            "photos": [
              {
                "id": 7,
                "imageUrl": "https://cdn.test/7.jpg",
                "userNickname": "토마토",
                "userProfileImageUrl": "https://cdn.test/u.jpg",
                "createdAt": "2026-08-03T13:38:42.959736"
              }
            ],
            "hasNext": false
          }
        }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultPhotoRepository(client: client)

        let photos = try await repository.photos(inRoom: 42)

        #expect(photos.count == 1)
        let photo = try #require(photos.first)
        #expect(photo.id == "7")
        #expect(photo.imageURL.absoluteString == "https://cdn.test/7.jpg")
        #expect(photo.author.nickname == "토마토")
        #expect(photo.reactions.isEmpty)

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/photos")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
        let query = request.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "roomId", value: "42")))
        #expect(query.contains(URLQueryItem(name: "page", value: "0")))
        #expect(query.contains(URLQueryItem(name: "size", value: "50")))
    }

    @Test("이미지 URL이 없는 사진은 건너뛴다 (한 장 때문에 목록 전체가 실패하지 않는다)")
    func skipsPhotosWithoutImage() async throws {
        let json = """
        {
          "success": true, "message": "ok",
          "data": {
            "photos": [
              { "id": 1, "imageUrl": null, "userNickname": "A", "createdAt": "2026-08-03T13:38:42" },
              { "id": 2, "imageUrl": "https://cdn.test/2.jpg", "userNickname": "B", "createdAt": "2026-08-03T13:38:42" }
            ],
            "hasNext": false
          }
        }
        """
        let repository = DefaultPhotoRepository(client: MockHTTPClient.returning(json: json))

        let photos = try await repository.photos(inRoom: 1)

        #expect(photos.map(\.id) == ["2"])
    }

    @Test("hasNext가 true면 다음 페이지를 이어 받는다")
    func followsPagination() async throws {
        let page0 = """
        { "success": true, "message": "ok", "data": { "photos": [
          { "id": 1, "imageUrl": "https://cdn.test/1.jpg", "userNickname": "A", "createdAt": "2026-08-03T13:38:42" }
        ], "hasNext": true } }
        """
        let page1 = """
        { "success": true, "message": "ok", "data": { "photos": [
          { "id": 2, "imageUrl": "https://cdn.test/2.jpg", "userNickname": "B", "createdAt": "2026-08-03T13:38:42" }
        ], "hasNext": false } }
        """
        let client = MockHTTPClient.succeeding([page0, page1])
        let repository = DefaultPhotoRepository(client: client)

        let photos = try await repository.photos(inRoom: 1)

        #expect(photos.map(\.id) == ["1", "2"])
        // 목록은 page=0 → page=1 순으로 이어 받는다. 목록만 부르고 리액션(상세)은 부르지 않는다.
        let listPages = client.requests.compactMap { $0.queryItems?.first { $0.name == "page" }?.value }
        #expect(listPages == ["0", "1"])
    }

    // MARK: - 사진별 리액션(지연 조회)

    @Test("사진 상세(chats)에서 유저별 첫 이모지는 스티커로, 종류 전체는 띠로 뽑는다")
    func mapsReactionsFromDetail() async throws {
        let detail = """
        { "success": true, "message": "ok", "data": { "photo": { "id": 7, "chats": [
          { "type": "EMOJI", "content": "heart", "userId": 1, "createdAt": "2026-08-03T13:38:40" },
          { "type": "EMOJI", "content": "fire", "userId": 1, "createdAt": "2026-08-03T13:38:45" },
          { "type": "COMMENT", "content": "hi", "userId": 2, "createdAt": "2026-08-03T13:38:41" }
        ] } } }
        """
        let client = MockHTTPClient.returning(json: detail)
        let repository = DefaultPhotoRepository(client: client)

        let reactions = try await repository.reactions(forPhotoID: "7")

        // 유저 1의 첫 이모지(heart)만 스티커. 두 번째(fire)·이모지 아닌 COMMENT는 스티커 아님.
        #expect(reactions.stickers == [PhotoReaction(kind: .heart, userID: "1")])
        // 띠에는 유저 1이 남긴 종류 전부.
        #expect(reactions.reactedKindsByUser == ["1": [.heart, .fire]])

        // 사진 하나만 상세로 부른다(목록 요청 없음) — 지연 조회의 핵심.
        let request = try #require(client.requests.first)
        #expect(client.requests.count == 1)
        #expect(request.path == "/api/v1/photos/7")
        #expect(request.method == .get)
    }

    // MARK: - 리액션

    @Test("리액션은 roomId·photoId·EMOJI·content를 담아 /chats/reaction에 POST한다")
    func postsReaction() async throws {
        let json = #"{ "success": true, "message": "ok", "data": { "chat": {} } }"#
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultPhotoRepository(client: client)

        try await repository.setReaction(roomID: 42, photoID: "7", kind: .heart, isOn: true)

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/chats/reaction")
        #expect(request.method == .post)
        #expect(request.usesBearerToken)

        let body = try #require(request.body)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let chat = try #require(payload?["chat"] as? [String: Any])
        #expect(chat["roomId"] as? Int == 42)
        #expect(chat["photoId"] as? Int == 7)
        #expect(chat["type"] as? String == "EMOJI")
        #expect(chat["content"] as? String == "heart")
    }

    @Test("해제(isOn == false)는 서버에 요청하지 않는다 (해제 API 미구현)")
    func removalIsNoOp() async throws {
        let client = MockHTTPClient.returning(json: #"{ "success": true, "message": "ok", "data": {} }"#)
        let repository = DefaultPhotoRepository(client: client)

        try await repository.setReaction(roomID: 42, photoID: "7", kind: .heart, isOn: false)

        #expect(client.requests.isEmpty)
    }

    // MARK: - 오류 정규화

    @Test("전송 실패는 PhotoError.network로 정규화된다")
    func normalizesTransportError() async {
        let client = MockHTTPClient.failing(NetworkError.transport(underlying: URLError(.notConnectedToInternet)))
        let repository = DefaultPhotoRepository(client: client)

        await #expect(throws: PhotoError.network) {
            try await repository.photos(inRoom: 1)
        }
    }

    @Test("401은 PhotoError.unauthorized로 정규화된다")
    func normalizesUnauthorized() async {
        let response = Response(statusCode: 401, data: Data())
        let client = MockHTTPClient.failing(NetworkError.unacceptableStatusCode(statusCode: 401, response: response))
        let repository = DefaultPhotoRepository(client: client)

        await #expect(throws: PhotoError.unauthorized) {
            try await repository.setReaction(roomID: 1, photoID: "7", kind: .fire, isOn: true)
        }
    }
}
