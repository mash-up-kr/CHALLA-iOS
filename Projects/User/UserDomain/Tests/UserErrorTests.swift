import Testing
import UserDomain

// UserError(networkError:) 매핑은 미래 UserData 소속이라 여기서 다루지 않는다 (규칙 6).
@Suite("UserError")
struct UserErrorTests {

    @Test("invalidNickname은 Violation의 문구를 그대로 쓴다")
    func invalidNicknameDelegatesToViolation() {
        #expect(
            UserError.invalidNickname(.tooLong(limit: 10)).userMessage
                == NicknameRule.Violation.tooLong(limit: 10).userMessage
        )
        #expect(UserError.invalidNickname(.empty).userMessage == "닉네임을 입력해 주세요.")
    }

    @Test("network·unauthorized·unknown은 고정 문구를 돌려준다")
    func fixedMessages() {
        #expect(UserError.network.userMessage == "네트워크 연결을 확인해 주세요.")
        #expect(UserError.unauthorized.userMessage == "인증에 실패했어요. 다시 시도해 주세요.")
        #expect(UserError.unknown.userMessage == "알 수 없는 오류가 발생했어요.")
    }

    @Test("server는 서버 메시지를 그대로 쓰고, 빈 메시지는 기본 문구로 대체한다")
    func serverMessage() {
        #expect(UserError.server(message: "이미 사용 중인 닉네임이에요.").userMessage == "이미 사용 중인 닉네임이에요.")
        #expect(UserError.server(message: "").userMessage == "프로필 저장에 실패했어요.")
    }
}
