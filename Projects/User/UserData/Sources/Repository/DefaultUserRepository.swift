import CHALLANetwork
import Foundation
import UserDomain

public struct DefaultUserRepository: UserRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func fetchMyProfile() async throws -> UserProfile {
        do {
            let response = try await client.request(
                UserEndpoint.me,
                as: BaseResponseDTO<UserProfileResponseDTO>.self
            )
            return try response.unwrap().toDomain()
        } catch {
            throw UserError.normalized(error)
        }
    }

    public func updateProfile(nickname: String, imageURL: URL?) async throws -> UserProfile {
        do {
            let requestDTO = UpdateProfileRequestDTO(
                nickname: nickname,
                profileImageUrl: imageURL?.absoluteString
            )
            let response = try await client.request(
                UserEndpoint.updateMe(requestDTO),
                as: BaseResponseDTO<UserProfileResponseDTO>.self
            )
            return try response.unwrap().toDomain()
        } catch {
            throw UserError.normalized(error)
        }
    }

    public func deleteAccount() async throws {
        do {
            let response = try await client.request(
                UserEndpoint.deleteMe,
                as: BaseResponseDTO<EmptyResponseDTO>.self
            )
            try response.ensureSuccess() // 탈퇴 응답에는 data가 없다 — 실패만 매핑
        } catch {
            throw UserError.normalized(error)
        }
    }
}
