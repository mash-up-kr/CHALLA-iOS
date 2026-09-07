@testable import ChatData
import CHALLANetwork
import ChatDomain
import Foundation
import PhotoDomain
import Testing

@Suite("DefaultChatRepository")
struct DefaultChatRepositoryTests {

    // MARK: - 조회

    @Test("목록을 도메인으로 변환하고 roomId 경로·page·size 쿼리를 싣는다")
    func mapsListWithPathAndQuery() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "DEFAULT", "content": "안녕", "photoImageUrl": null,
            "createdAt": "2026-08-03T13:38:42", "userName": "토마토",
            "userProfileImageUrl": "https://cdn.test/u.jpg" }
        ] } }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultChatRepository(client: client)

        let messages = try await repository.messages(inRoom: 42, page: 0, size: 30)

        #expect(messages.count == 1)
        let message = try #require(messages.first)
        #expect(message.kind == .text)
        #expect(message.content == "안녕")
        #expect(message.authorName == "토마토")

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/chats/42")
        #expect(request.method == .get)
        #expect(request.usesBearerToken)
        let query = request.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "page", value: "0")))
        #expect(query.contains(URLQueryItem(name: "size", value: "30")))
    }

    @Test("사진 URL과 텍스트가 함께 오면 사진 메시지로 매핑하고 텍스트도 보존한다")
    func mapsPhotoMessageWithText() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "DEFAULT", "content": "이 사진 좋다", "photoImageUrl": "https://cdn.test/7.jpg",
            "createdAt": "2026-08-03T13:38:42", "userName": "토마토", "userProfileImageUrl": null }
        ] } }
        """
        let repository = DefaultChatRepository(client: MockHTTPClient.returning(json: json))

        let message = try #require(try await repository.messages(inRoom: 1, page: 0, size: 10).first)
        // 사진 카드 + 텍스트 버블을 함께 그리려면 kind가 .photo이고 content가 남아 있어야 한다.
        #expect(message.kind == .photo)
        #expect(message.photoImageURL?.absoluteString == "https://cdn.test/7.jpg")
        #expect(message.content == "이 사진 좋다")
    }

    @Test("photoImageUrl이 빈 문자열이면 사진이 없는 텍스트 메시지로 매핑한다")
    func emptyPhotoUrlIsText() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "DEFAULT", "content": "안녕", "photoImageUrl": "",
            "createdAt": "2026-08-03T13:38:42", "userName": "토마토", "userProfileImageUrl": null }
        ] } }
        """
        let repository = DefaultChatRepository(client: MockHTTPClient.returning(json: json))

        let message = try #require(try await repository.messages(inRoom: 1, page: 0, size: 10).first)
        #expect(message.kind == .text)
        #expect(message.photoImageURL == nil)
    }

    @Test("EMOJI 타입은 사진에 달린 이모지 리액션으로 매핑한다")
    func mapsEmojiReaction() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "EMOJI", "content": "heart", "photoImageUrl": "https://cdn.test/7.jpg",
            "createdAt": "2026-08-03T13:38:42", "userName": "토마토", "userProfileImageUrl": null }
        ] } }
        """
        let repository = DefaultChatRepository(client: MockHTTPClient.returning(json: json))

        let message = try #require(try await repository.messages(inRoom: 1, page: 0, size: 10).first)
        #expect(message.kind == .reaction(.heart))
        #expect(message.photoImageURL?.absoluteString == "https://cdn.test/7.jpg")
    }

    @Test("알 수 없는 EMOJI content는 건너뛴다")
    func skipsUnknownEmoji() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "EMOJI", "content": "unknown_kind", "photoImageUrl": "https://cdn.test/7.jpg",
            "createdAt": "2026-08-03T13:38:42", "userName": "토마토", "userProfileImageUrl": null }
        ] } }
        """
        let repository = DefaultChatRepository(client: MockHTTPClient.returning(json: json))

        let messages = try await repository.messages(inRoom: 1, page: 0, size: 10)
        #expect(messages.isEmpty)
    }

    @Test("보낸 사람 이름이 없는 항목은 건너뛴다")
    func skipsMessagesWithoutAuthor() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "DEFAULT", "content": "x", "photoImageUrl": null,
            "createdAt": "2026-08-03T13:38:42", "userName": null, "userProfileImageUrl": null },
          { "type": "DEFAULT", "content": "y", "photoImageUrl": null,
            "createdAt": "2026-08-03T13:38:42", "userName": "B", "userProfileImageUrl": null }
        ] } }
        """
        let repository = DefaultChatRepository(client: MockHTTPClient.returning(json: json))

        let messages = try await repository.messages(inRoom: 1, page: 0, size: 10)
        #expect(messages.map(\.content) == ["y"])
    }

    // MARK: - 작성

    @Test("사진에 보낸 메시지는 /chats/reaction 으로 COMMENT를 POST한다")
    func sendsMessage() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chat":
          { "type": "DEFAULT", "content": "보냄", "photoImageUrl": null,
            "createdAt": "2026-08-03T13:38:42", "userName": "나", "userProfileImageUrl": null }
        } }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultChatRepository(client: client)

        try await repository.send(roomID: 42, photoID: 7, content: "보냄")

        let request = try #require(client.requests.first)
        #expect(request.path == "/api/v1/chats/reaction")
        #expect(request.method == .post)
        #expect(request.usesBearerToken)

        let body = try #require(request.body)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let chat = try #require(payload?["chat"] as? [String: Any])
        #expect(chat["roomId"] as? Int == 42)
        #expect(chat["photoId"] as? Int == 7)
        #expect(chat["type"] as? String == "COMMENT")
        #expect(chat["content"] as? String == "보냄")
    }

    @Test("photoID가 nil이면 photoId를 0으로 보낸다 (방 단위 메시지)")
    func sendsZeroPhotoIDWhenNil() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chat":
          { "type": "DEFAULT", "content": "방메시지", "photoImageUrl": null,
            "createdAt": "2026-08-03T13:38:42", "userName": "나", "userProfileImageUrl": null } } }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultChatRepository(client: client)

        try await repository.send(roomID: 1, photoID: nil, content: "방메시지")

        let body = try #require(client.requests.first?.body)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let chat = try #require(payload?["chat"] as? [String: Any])
        #expect(chat["photoId"] as? Int == 0)
        #expect(chat["type"] as? String == "DEFAULT")
        #expect(client.requests.first?.path == "/api/v1/chats")
    }

    @Test("COMMENT는 사진과 글을 함께 보여주는 사진 메시지로 매핑한다")
    func mapsCommentAsPhotoMessage() async throws {
        let json = """
        { "success": true, "message": "ok", "data": { "chats": [
          { "type": "COMMENT", "content": "이 사진 좋다", "photoImageUrl": "https://cdn.test/7.jpg",
            "createdAt": "2026-08-03T13:38:42", "userName": "나", "userProfileImageUrl": null }
        ] } }
        """
        let client = MockHTTPClient.returning(json: json)
        let repository = DefaultChatRepository(client: client)

        let messages = try await repository.messages(inRoom: 42, page: 0, size: 20)

        let message = try #require(messages.first)
        #expect(message.kind == .photo)
        #expect(message.content == "이 사진 좋다")
        #expect(message.photoImageURL?.absoluteString == "https://cdn.test/7.jpg")
    }

    // MARK: - 오류 정규화

    @Test("전송 실패는 ChatError.network로 정규화된다")
    func normalizesTransportError() async {
        let client = MockHTTPClient.failing(NetworkError.transport(underlying: URLError(.notConnectedToInternet)))
        let repository = DefaultChatRepository(client: client)

        await #expect(throws: ChatError.network) {
            try await repository.messages(inRoom: 1, page: 0, size: 10)
        }
    }

    @Test("401은 ChatError.unauthorized로 정규화된다")
    func normalizesUnauthorized() async {
        let response = Response(statusCode: 401, data: Data())
        let client = MockHTTPClient.failing(NetworkError.unacceptableStatusCode(statusCode: 401, response: response))
        let repository = DefaultChatRepository(client: client)

        await #expect(throws: ChatError.unauthorized) {
            try await repository.send(roomID: 1, photoID: nil, content: "x")
        }
    }
}
