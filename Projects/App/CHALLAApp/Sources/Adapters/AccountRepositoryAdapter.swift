import AuthDomain
import SettingDomain
import UserDomain

/// `AccountRepository` 구현 — 계정 관리 화면의 로그아웃·회원 탈퇴.
///
/// **여기 있는 이유** — 로그아웃은 Auth aggregate(`LogoutUseCase`), 탈퇴는 User aggregate
/// (`UserRepository.deleteAccount`)라 둘을 조합하는 이 동작에는 단일 Domain 홈이 없다.
/// `AccountRepository` 주석도 실행 앱의 `CompositionRoot`가 어댑터를 주입하도록 지시하고 있다.
struct AccountRepositoryAdapter: AccountRepository {

    private let logout: LogoutUseCase
    private let userRepository: any UserRepository
    private let tokenStore: any TokenStore
    /// 탈퇴·로그아웃 후 이 기기로 더는 푸시가 오지 않게 한다.
    private let clearPushToken: @Sendable () async -> Void

    init(
        logout: LogoutUseCase,
        userRepository: any UserRepository,
        tokenStore: any TokenStore,
        clearPushToken: @escaping @Sendable () async -> Void
    ) {
        self.logout = logout
        self.userRepository = userRepository
        self.tokenStore = tokenStore
        self.clearPushToken = clearPushToken
    }

    /// `LogoutUseCase`가 서버 로그아웃과 토큰 삭제까지 한다.
    func signOut() async throws {
        // 세션이 끊기면 이 토큰으로는 해제 API를 부를 수 없다 — 먼저 정리한다.
        await clearPushToken()
        do {
            try await logout.run()
        } catch {
            throw SettingError(accountError: error)
        }
    }

    /// 탈퇴 API는 서버 계정만 지운다 — **로컬 토큰은 여기서 지워야 한다.**
    /// 안 지우면 탈퇴 후에도 죽은 토큰이 Keychain에 남아 다음 실행에서 401을 맞는다.
    func deleteAccount() async throws {
        await clearPushToken()
        do {
            try await userRepository.deleteAccount()
        } catch {
            throw SettingError(accountError: error)
        }
        // 서버 계정이 사라진 뒤라 토큰 삭제 실패는 되돌릴 수 없다.
        // 다음 실행의 프로필 조회가 401을 받아 로그인 화면으로 보내므로 여기서는 무시한다.
        try? tokenStore.clear()
    }
}

private extension SettingError {

    /// 로그아웃·탈퇴가 던지는 두 도메인 오류(`AuthError`·`UserError`)를 한 곳에서 매핑한다.
    init(accountError error: any Error) {
        switch error {
        case AuthError.network, UserError.network:
            self = .network
        default:
            self = .unknown
        }
    }
}
