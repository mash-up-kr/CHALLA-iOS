import Dependencies
import DependenciesMacros

// 계정 관리 화면이 쓰는 UseCase 2종.

// MARK: - 로그아웃

/// 세션을 지운다. 성공하면 App이 로그인 화면으로 되돌린다.
@DependencyClient
public struct SignOutUseCase: Sendable {
    /// 실패는 `SettingError`로 정규화되어 온다 (`AccountRepository` 계약).
    public var run: @Sendable () async throws -> Void
}

extension SignOutUseCase: TestDependencyKey {

    public static func live(account: any AccountRepository) -> SignOutUseCase {
        SignOutUseCase(run: {
            try await account.signOut()
        })
    }

    public static let testValue = SignOutUseCase()

    public static let previewValue = SignOutUseCase(run: {})
}

public extension DependencyValues {
    var signOutUseCase: SignOutUseCase {
        get { self[SignOutUseCase.self] }
        set { self[SignOutUseCase.self] = newValue }
    }
}

// MARK: - 회원 탈퇴

/// 계정을 삭제한다. 되돌릴 수 없어 화면이 확인 드로어를 한 번 거친다.
@DependencyClient
public struct DeleteAccountUseCase: Sendable {
    public var run: @Sendable () async throws -> Void
}

extension DeleteAccountUseCase: TestDependencyKey {

    public static func live(account: any AccountRepository) -> DeleteAccountUseCase {
        DeleteAccountUseCase(run: {
            try await account.deleteAccount()
        })
    }

    public static let testValue = DeleteAccountUseCase()

    public static let previewValue = DeleteAccountUseCase(run: {})
}

public extension DependencyValues {
    var deleteAccountUseCase: DeleteAccountUseCase {
        get { self[DeleteAccountUseCase.self] }
        set { self[DeleteAccountUseCase.self] = newValue }
    }
}
