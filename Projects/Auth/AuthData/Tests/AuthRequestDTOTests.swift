@testable import AuthData
import AuthDomain
import Foundation
import Testing

/// 서버 enum 문자열 매핑(`"KAKAO"`/`"APPLE"`)은 Data 레이어의 계약이다 —
/// Domain의 `AuthProvider`(kakao/apple)를 서버 표기로 바꾸는 유일한 지점이라 별도로 고정한다.
@Suite("LoginRequestDTO")
struct AuthRequestDTOTests {

    @Test("kakao는 provider를 \"KAKAO\"로 매핑하고 나머지 값을 그대로 싣는다")
    func kakaoMapping() {
        let dto = LoginRequestDTO(from: SocialCredential(
            provider: .kakao,
            idToken: "id-token",
            authorizationCode: nil
        ))

        #expect(dto.auth.provider == "KAKAO")
        #expect(dto.auth.idToken == "id-token")
        #expect(dto.auth.authorizationCode == nil)
    }

    @Test("apple은 provider를 \"APPLE\"로 매핑하고 authorizationCode를 함께 싣는다")
    func appleMapping() {
        let dto = LoginRequestDTO(from: SocialCredential(
            provider: .apple,
            idToken: "identity-token",
            authorizationCode: "auth-code"
        ))

        #expect(dto.auth.provider == "APPLE")
        #expect(dto.auth.idToken == "identity-token")
        #expect(dto.auth.authorizationCode == "auth-code")
    }

    @Test("JSON으로 인코딩하면 auth 키로 감싼 서버 표기가 된다")
    func encodesToServerShape() throws {
        let dto = LoginRequestDTO(from: SocialCredential(
            provider: .kakao,
            idToken: "id-token",
            authorizationCode: nil
        ))

        let data = try JSONEncoder().encode(dto)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let auth = try #require(root["auth"] as? [String: Any])

        #expect(auth["provider"] as? String == "KAKAO")
        #expect(auth["idToken"] as? String == "id-token")
    }
}
