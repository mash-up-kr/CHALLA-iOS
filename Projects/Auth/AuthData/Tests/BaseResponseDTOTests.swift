@testable import AuthData
import AuthDomain
import CHALLANetwork
import Foundation
import Testing

@Suite("BaseResponseDTO")
struct BaseResponseDTOTests {

    @Test("success + data가 있으면 unwrap이 payload를 돌려준다")
    func unwrapSuccess() throws {
        let json = """
        {"success": true, "message": "ok", "data": {"auth": {"accessToken": "a", "refreshToken": "r", "isNew": true}}}
        """
        let response = try JSONDecoder().decode(
            BaseResponseDTO<LoginResponseDTO>.self,
            from: Data(json.utf8)
        )

        let payload = try response.unwrap()

        #expect(payload.auth.accessToken == "a")
        #expect(payload.auth.refreshToken == "r")
        #expect(payload.auth.isNew == true)
    }

    @Test("success=false면 unwrap이 서버 메시지를 담은 .server를 던진다")
    func unwrapServerFailure() throws {
        let json = """
        {"success": false, "message": "이미 탈퇴한 계정이에요.", "data": null}
        """
        let response = try JSONDecoder().decode(
            BaseResponseDTO<LoginResponseDTO>.self,
            from: Data(json.utf8)
        )

        #expect(throws: AuthError.server(message: "이미 탈퇴한 계정이에요.")) {
            _ = try response.unwrap()
        }
    }

    @Test("success=true여도 data가 없으면 unwrap은 .server를 던진다")
    func unwrapMissingData() throws {
        let json = """
        {"success": true, "message": "ok", "data": null}
        """
        let response = try JSONDecoder().decode(
            BaseResponseDTO<LoginResponseDTO>.self,
            from: Data(json.utf8)
        )

        #expect(throws: AuthError.server(message: "ok")) {
            _ = try response.unwrap()
        }
    }

    @Test("ensureSuccess는 data가 null이어도 success면 통과한다")
    func ensureSuccessIgnoresPayload() throws {
        let json = """
        {"success": true, "message": "ok", "data": null}
        """
        let response = try JSONDecoder().decode(
            BaseResponseDTO<EmptyResponseDTO>.self,
            from: Data(json.utf8)
        )

        try response.ensureSuccess() // throw되면 테스트 실패
    }

    @Test("ensureSuccess는 success=false면 .server를 던진다")
    func ensureSuccessFailure() throws {
        let json = """
        {"success": false, "message": "세션이 만료됐어요.", "data": null}
        """
        let response = try JSONDecoder().decode(
            BaseResponseDTO<EmptyResponseDTO>.self,
            from: Data(json.utf8)
        )

        #expect(throws: AuthError.server(message: "세션이 만료됐어요.")) {
            try response.ensureSuccess()
        }
    }
}
