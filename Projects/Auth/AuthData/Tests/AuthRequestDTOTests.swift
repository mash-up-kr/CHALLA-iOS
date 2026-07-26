import Testing
import Foundation
import AuthDomain
@testable import AuthData

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

        #expect(dto.provider == "KAKAO")
        #expect(dto.idToken == "id-token")
        #expect(dto.authorizationCode == nil)
    }

    @Test("apple은 provider를 \"APPLE\"로 매핑하고 authorizationCode를 함께 싣는다")
    func appleMapping() {
        let dto = LoginRequestDTO(from: SocialCredential(
            provider: .apple,
            idToken: "identity-token",
            authorizationCode: "auth-code"
        ))

        #expect(dto.provider == "APPLE")
        #expect(dto.idToken == "identity-token")
        #expect(dto.authorizationCode == "auth-code")
    }

    @Test("JSON으로 인코딩하면 서버 표기 그대로 직렬화된다")
    func encodesToServerShape() throws {
        let dto = LoginRequestDTO(from: SocialCredential(
            provider: .kakao,
            idToken: "id-token",
            authorizationCode: nil
        ))

        let data = try JSONEncoder().encode(dto)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["provider"] as? String == "KAKAO")
        #expect(json["idToken"] as? String == "id-token")
    }
}
