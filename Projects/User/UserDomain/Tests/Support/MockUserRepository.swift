import Foundation
import os
import UserDomain

/// 호출을 캡처하고 지정한 결과를 돌려주는 `UserRepository` 목.
///
/// `UserRepository` 규약대로 실패는 항상 `UserError`로 던진다.
/// `Sendable`을 `@unchecked` 없이 만족시키기 위해 가변 상태를 락으로 감싼다
/// (AuthDomain의 MockAuthRepository와 같은 방식 — iOS 17 타깃이라 `OSAllocatedUnfairLock`).
final class MockUserRepository: UserRepository {

    struct Update: Equatable, Sendable {
        let nickname: String
        let imageURL: URL?
    }

    private let state = OSAllocatedUnfairLock(initialState: [Update]())
    private let fetchResult: Result<UserProfile, UserError>
    private let updateResult: Result<UserProfile, UserError>

    init(
        fetchResult: Result<UserProfile, UserError> = .failure(.unknown),
        updateResult: Result<UserProfile, UserError> = .failure(.unknown)
    ) {
        self.fetchResult = fetchResult
        self.updateResult = updateResult
    }

    /// updateProfile이 받은 인자 (호출 순서대로).
    var updates: [Update] {
        state.withLock { $0 }
    }

    func fetchMyProfile() async throws -> UserProfile {
        try fetchResult.get()
    }

    func updateProfile(nickname: String, imageURL: URL?) async throws -> UserProfile {
        state.withLock { $0.append(Update(nickname: nickname, imageURL: imageURL)) }
        return try updateResult.get()
    }

    func deleteAccount() async throws {}
}

/// 업로드 호출을 캡처하고 지정한 결과를 돌려주는 `ProfileImageUploader` 목.
final class MockProfileImageUploader: ProfileImageUploader {

    private let state = OSAllocatedUnfairLock(initialState: [Data]())
    private let result: Result<URL, UserError>

    init(result: Result<URL, UserError>) {
        self.result = result
    }

    /// upload에 전달된 이미지 (호출 순서대로).
    var uploaded: [Data] {
        state.withLock { $0 }
    }

    func upload(_ imageData: Data) async throws -> URL {
        state.withLock { $0.append(imageData) }
        return try result.get()
    }
}
