import Foundation

/// 유저 프로필 저장소 인터페이스 (구현: `UserData`).
public protocol UserRepository: Sendable {
    /// 내 프로필 조회. 앱 진입 시 프로필 설정 완료 여부를 판별하는 근거가 된다.
    func fetchMyProfile() async throws -> UserProfile

    /// 프로필 설정·수정. 이미지는 `ProfileImageUploader`가 먼저 올린 공개 URL로 받는다.
    /// 실패는 반드시 `UserError`로 정규화해 던진다.
    func updateProfile(nickname: String, imageURL: URL?) async throws -> UserProfile

    func deleteAccount() async throws
}
