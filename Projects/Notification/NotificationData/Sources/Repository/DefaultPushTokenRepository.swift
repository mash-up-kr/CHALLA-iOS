import CHALLANetwork
import Foundation
import NotificationDomain

/// `PushTokenRepository` 구현 — 알림 서버 호출 + 오류 정규화.
///
/// 밖으로 던지는 오류는 취소를 제외하면 전부 `NotificationError`다 (Domain 규약).
public struct DefaultPushTokenRepository: PushTokenRepository {

    // MARK: - Properties

    /// 라이브는 `DefaultHTTPClient`, 테스트는 Mock을 주입한다.
    private let client: any HTTPClient

    // MARK: - Init

    public init(client: any HTTPClient) {
        self.client = client
    }

    // MARK: - Public Methods

    public func register(token: String) async throws {
        try await sendWithoutPayload(.registerToken(DeviceTokenRequestDTO(token: token)))
    }

    public func unregister(token: String) async throws {
        try await sendWithoutPayload(.deleteToken(DeviceTokenRequestDTO(token: token)))
    }

    #if DEBUG
        public func sendTestPush(title: String, body: String) async throws -> Int {
            do {
                let envelope = try await client.request(
                    NotificationEndpoint.sendTest(TestPushRequestDTO(title: title, body: body)),
                    as: BaseResponseDTO<TestPushResponseDTO>.self
                )
                return try envelope.unwrap().notification.sentCount
            } catch {
                throw NotificationError.normalized(error)
            }
        }
    #endif

    // MARK: - Private Methods

    /// 등록·해제는 응답에 `data`가 없어 성공 여부만 본다.
    private func sendWithoutPayload(_ endpoint: NotificationEndpoint) async throws {
        do {
            let envelope = try await client.request(
                endpoint,
                as: BaseResponseDTO<EmptyResponseDTO>.self
            )
            try envelope.ensureSuccess()
        } catch {
            throw NotificationError.normalized(error)
        }
    }
}
