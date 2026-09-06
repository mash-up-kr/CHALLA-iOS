@testable import ChatData
import ChatDomain
import Foundation
import Testing

@Suite("ChatEventSubscriber — 채팅 이벤트 디코딩")
struct ChatEventSubscriberTests {

    private let subscriber = ChatEventSubscriber(client: StubSTOMPClient())

    @Test("REST와 같은 봉투로 온 채팅을 도메인으로 바꾼다")
    func decodesEnvelope() throws {
        let json = """
        { "success": true, "message": "OK", "data": { "chat":
          { "chatId": 157, "userId": 3, "type": "EMOJI", "content": "thumbsUp",
            "photoId": 1, "photoImageUrl": "https://cdn.test/1.jpg",
            "createdAt": "2026-08-24T20:01:25.667675", "userName": "ㅌㅅㅌㅅ",
            "userProfileImageUrl": null } } }
        """
        let message = try #require(subscriber.decode(Data(json.utf8)))

        #expect(message.id == .server(157))
        #expect(message.authorID == 3)
        #expect(message.kind == .reaction(.thumbsUp))
    }

    @Test("봉투 없이 온 형태도 받아 준다")
    func decodesBarePayload() throws {
        let json = """
        { "chat": { "chatId": 2, "userId": 9, "type": "DEFAULT", "content": "안녕",
          "createdAt": "2026-08-24T20:01:25", "userName": "연준" } }
        """
        let message = try #require(subscriber.decode(Data(json.utf8)))

        #expect(message.id == .server(2))
        #expect(message.content == "안녕")
    }

    @Test("chatId가 없으면 nil로 흘려보낸다 (중복 제거 키가 없어 쓸 수 없다)")
    func returnsNilWithoutServerID() {
        let json = """
        { "chat": { "userId": 9, "type": "DEFAULT", "content": "안녕",
          "createdAt": "2026-08-24T20:01:25", "userName": "연준" } }
        """
        #expect(subscriber.decode(Data(json.utf8)) == nil)
    }

    @Test("해석할 수 없는 본문은 nil로 흘려보낸다 (스트림을 죽이지 않는다)")
    func returnsNilForGarbage() {
        #expect(subscriber.decode(Data("깨진본문".utf8)) == nil)
    }
}
