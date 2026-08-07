@testable import UserData
import CHALLANetwork
import Foundation
import Testing
import UserDomain

@Suite("DefaultUserRepository")
struct DefaultUserRepositoryTests {

    private static let profileJSON = """
    {"success":true,"message":"OK","data":{"user":{"id":7,"nickname":"챌라","profileImageUrl":"https://example.com/p.png"}}}
    """

    // MARK: - fetchMyProfile

    @Test("조회 성공 — GET /api/v1/users/me를 호출하고 응답을 도메인으로 매핑한다")
    func fetchMapsResponse() async throws {
        let client = MockHTTPClient.returning(json: Self.profileJSON)

        let profile = try await DefaultUserRepository(client: client).fetchMyProfile()

        #expect(profile.id == 7)
        #expect(profile.nickname == "챌라")
        #expect(profile.imageURL == URL(string: "https://example.com/p.png"))
        #expect(client.requests.map(\.path) == ["/api/v1/users/me"])
        #expect(client.requests.map(\.method) == [.get])
    }

    @Test("닉네임 미설정 — nickname이 null이면 nil로 매핑되어 프로필 미완료로 판별된다")
    func fetchMapsNullNickname() async throws {
        let client = MockHTTPClient.returning(
            json: #"{"success":true,"message":"OK","data":{"user":{"id":7,"nickname":null,"profileImageUrl":null}}}"#
        )

        let profile = try await DefaultUserRepository(client: client).fetchMyProfile()

        #expect(profile.nickname == nil)
        #expect(profile.imageURL == nil)
        #expect(profile.isProfileCompleted == false)
    }

    // MARK: - updateProfile

    @Test("설정 성공 — PUT 본문을 user 키로 감싸고, profileImageUrl 키를 null로 채워 넣는다")
    func updateSendsContractedBody() async throws {
        let client = MockHTTPClient.returning(json: Self.profileJSON)

        let profile = try await DefaultUserRepository(client: client)
            .updateProfile(nickname: "챌라", imageURL: nil)

        #expect(profile.nickname == "챌라")
        #expect(client.requests.map(\.method) == [.put])

        let body = try #require(client.requests.first?.body)
        let root = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let user = try #require(root["user"] as? [String: Any]) // 서버 규약대로 user 키로 감싼다
        #expect(user["nickname"] as? String == "챌라")
        #expect(user.keys.contains("profileImageUrl"))
        #expect(user["profileImageUrl"] is NSNull)
    }

    // MARK: - deleteAccount

    @Test("탈퇴 성공 — DELETE를 호출한다")
    func deleteCallsEndpoint() async throws {
        let client = MockHTTPClient.returning(json: #"{"success":true,"message":"OK"}"#)

        try await DefaultUserRepository(client: client).deleteAccount()

        #expect(client.requests.map(\.path) == ["/api/v1/users/me"])
        #expect(client.requests.map(\.method) == [.delete])
    }

    // MARK: - 오류 정규화

    @Test("success:false — 서버 message를 담은 UserError.server로 정규화된다")
    func serverFailureCarriesMessage() async {
        let client = MockHTTPClient.returning(json: #"{"success":false,"message":"닉네임 중복","data":null}"#)

        await #expect(throws: UserError.server(message: "닉네임 중복")) {
            _ = try await DefaultUserRepository(client: client).fetchMyProfile()
        }
    }

    @Test("401 — UserError.unauthorized로 정규화된다")
    func unauthorizedIsNormalized() async {
        let client = MockHTTPClient.returning(statusCode: 401, json: "{}")

        await #expect(throws: UserError.unauthorized) {
            _ = try await DefaultUserRepository(client: client).fetchMyProfile()
        }
    }

    @Test("전송 실패 — UserError.network로 정규화된다")
    func transportErrorIsNormalized() async {
        let client = MockHTTPClient.failing(
            NetworkError.transport(underlying: URLError(.notConnectedToInternet))
        )

        await #expect(throws: UserError.network) {
            _ = try await DefaultUserRepository(client: client).fetchMyProfile()
        }
    }

    @Test("취소 — UserError로 뭉개지 않고 CancellationError 그대로 전파한다")
    func cancellationPropagates() async {
        let client = MockHTTPClient.failing(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await DefaultUserRepository(client: client).fetchMyProfile()
        }
    }
}
