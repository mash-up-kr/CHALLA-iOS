import RoomDomain
import Testing

/// 서버 오류 → RoomError 정규화는 RoomData 소속이므로 여기서 다루지 않는다 (규칙 6).
@Suite("RoomError")
struct RoomErrorTests {

    @Test("연관값 없는 케이스는 고정 문구를 돌려준다")
    func fixedMessages() {
        #expect(RoomError.network.userMessage == "네트워크 연결을 확인해 주세요.")
        #expect(RoomError.unauthorized.userMessage == "다시 로그인해 주세요.")
        #expect(RoomError.invalidRoomName.userMessage == "방 이름을 입력해 주세요.")
        #expect(RoomError.invalidInviteCode.userMessage == "초대 코드를 입력해 주세요.")
        #expect(RoomError.roomNotFound.userMessage == "초대 코드를 다시 확인해 주세요.")
        #expect(RoomError.roomFull.userMessage == "이 방은 인원이 가득 찼어요.")
        #expect(RoomError.unknown.userMessage == "알 수 없는 오류가 발생했어요.")
    }

    @Test("server는 서버 메시지를 그대로 쓰고, 빈 메시지는 기본 문구로 대체한다")
    func serverMessage() {
        #expect(RoomError.server(message: "정원이 가득 찬 방이에요.").userMessage == "정원이 가득 찬 방이에요.")
        #expect(RoomError.server(message: "").userMessage == "잠시 후 다시 시도해 주세요.")
    }

    @Test("동등성은 연관값까지 비교한다")
    func equality() {
        #expect(RoomError.server(message: "a") == RoomError.server(message: "a"))
        #expect(RoomError.server(message: "a") != RoomError.server(message: "b"))
        #expect(RoomError.roomNotFound != RoomError.roomFull)
    }
}
