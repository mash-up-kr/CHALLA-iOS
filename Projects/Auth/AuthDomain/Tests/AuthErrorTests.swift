import AuthDomain
import Testing

// AuthError(networkError:) 매핑은 AuthData 소속이므로 여기서 다루지 않는다 (규칙 6).
@Suite("AuthError")
struct AuthErrorTests {

    @Test("cancelled의 userMessage는 빈 문자열이다 (얼럿 미표시)")
    func cancelledMessageIsEmpty() {
        #expect(AuthError.cancelled.userMessage == "")
    }

    @Test("network·unauthorized·unknown은 고정 문구를 돌려준다")
    func fixedMessages() {
        #expect(AuthError.network.userMessage == "네트워크 연결을 확인해 주세요.")
        #expect(AuthError.unauthorized.userMessage == "인증에 실패했어요. 다시 시도해 주세요.")
        #expect(AuthError.unknown.userMessage == "알 수 없는 오류가 발생했어요.")
    }

    @Test("server는 서버 메시지를 그대로 쓰고, 빈 메시지는 기본 문구로 대체한다")
    func serverMessage() {
        #expect(AuthError.server(message: "이미 탈퇴한 계정이에요.").userMessage == "이미 탈퇴한 계정이에요.")
        #expect(AuthError.server(message: "").userMessage == "로그인에 실패했어요.")
    }

    @Test("social은 SDK 사유를 그대로 쓰고, 빈 사유는 기본 문구로 대체한다")
    func socialMessage() {
        #expect(AuthError.social(reason: "Kakao idToken을 받지 못했어요.").userMessage == "Kakao idToken을 받지 못했어요.")
        #expect(AuthError.social(reason: "").userMessage == "소셜 로그인에 실패했어요.")
    }

    @Test("동등성은 연관값까지 비교한다")
    func equality() {
        #expect(AuthError.server(message: "a") == AuthError.server(message: "a"))
        #expect(AuthError.server(message: "a") != AuthError.server(message: "b"))
        #expect(AuthError.social(reason: "a") != AuthError.server(message: "a"))
        #expect(AuthError.cancelled != AuthError.unknown)
    }
}
