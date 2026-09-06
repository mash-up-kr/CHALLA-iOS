@testable import RoomData
import Foundation
import RoomDomain
import Testing

@Suite("RoomEventSubscriber — 참여 이벤트 디코딩")
struct RoomEventSubscriberTests {

    private let subscriber = RoomEventSubscriber(client: StubSTOMPClient())

    @Test("REST와 같은 봉투로 온 참여 이벤트를 도메인으로 바꾼다")
    func decodesEnvelope() throws {
        let json = """
        { "success": true, "message": "ok", "data": { "room":
          { "id": 1, "title": "Trip", "userNickname": "내꺼",
            "userProfileImageUrl": "https://cdn.test/u.jpg" } } }
        """
        let joined = try #require(subscriber.decode(Data(json.utf8)))

        #expect(joined.roomID == 1)
        #expect(joined.roomTitle == "Trip")
        #expect(joined.nickname == "내꺼")
        #expect(joined.profileImageURL?.absoluteString == "https://cdn.test/u.jpg")
    }

    @Test("userId가 오면 담고, 없으면 nil로 둔다 (서버가 나중에 추가해도 앱 수정 없이 쓰인다)")
    func decodesOptionalUserID() throws {
        let withID = """
        { "room": { "id": 1, "title": "T", "userId": 42, "userNickname": "연준", "userProfileImageUrl": null } }
        """
        let withoutID = """
        { "room": { "id": 1, "title": "T", "userNickname": "연준", "userProfileImageUrl": null } }
        """
        #expect(try #require(subscriber.decode(Data(withID.utf8))).userID == 42)
        #expect(try #require(subscriber.decode(Data(withoutID.utf8))).userID == nil)
    }

    @Test("봉투 없이 온 형태도 받아 준다")
    func decodesBarePayload() throws {
        let json = """
        { "room": { "id": 2, "title": "강릉", "userNickname": "연준", "userProfileImageUrl": null } }
        """
        let joined = try #require(subscriber.decode(Data(json.utf8)))

        #expect(joined.roomID == 2)
        #expect(joined.profileImageURL == nil)
    }

    @Test("해석할 수 없는 본문은 nil로 흘려보낸다 (스트림을 죽이지 않는다)")
    func returnsNilForGarbage() {
        #expect(subscriber.decode(Data("{}".utf8)) == nil)
        #expect(subscriber.decode(Data("깨진본문".utf8)) == nil)
    }
}
