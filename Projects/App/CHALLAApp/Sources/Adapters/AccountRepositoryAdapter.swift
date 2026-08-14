import AuthDomain
import SettingDomain
import UserDomain

/// `AccountRepository` 구현 — 계정 관리 화면의 로그아웃·회원 탈퇴.
///
/// 로그아웃은 `AuthDomain`, 탈퇴는 `UserDomain`이 갖고 있다.
/// 둘 다 아는 곳이 App뿐이라 여기서 합친다.
struct AccountRepositoryAdapter: AccountRepository {

    private let logout: LogoutUseCase
    private let userRepository: any UserRepository
    private let tokenStore: any TokenStore
    private let pushToken: PushTokenControl
    /// 세션이 바뀌면 이전 계정의 프로필·방 이미지가 캐시에 남지 않게 비운다.
    private let clearImageCache: @Sendable () async -> Void

    /// 푸시 토큰은 세션이 살아 있을 때만 해제할 수 있어서 로그아웃보다 먼저 지운다.
    /// 그런데 로그아웃이 실패하면 사용자는 로그인 상태로 남으므로, 지운 토큰을 되돌려야 한다.
    struct PushTokenControl: Sendable {
        /// 서버에서 이 기기 토큰을 지운다.
        var clear: @Sendable () async -> Void
        /// 저장된 알림 설정대로 다시 등록한다. 실패해도 알리지 않고 다음 앱 실행에 맡긴다.
        var restore: @Sendable () async -> Void
    }

    init(
        logout: LogoutUseCase,
        userRepository: any UserRepository,
        tokenStore: any TokenStore,
        pushToken: PushTokenControl,
        clearImageCache: @escaping @Sendable () async -> Void
    ) {
        self.logout = logout
        self.userRepository = userRepository
        self.tokenStore = tokenStore
        self.pushToken = pushToken
        self.clearImageCache = clearImageCache
    }

    /// `LogoutUseCase`가 서버 로그아웃과 토큰 삭제까지 한다.
    func signOut() async throws {
        // 세션이 끊기면 이 토큰으로는 해제 API를 부를 수 없다 — 먼저 정리한다.
        await pushToken.clear()
        do {
            try await logout.run()
        } catch {
            // 로그인 상태로 남았는데 푸시만 끊기면 다음 실행 전까지 알림이 오지 않는다.
            await pushToken.restore()
            throw SettingError(accountError: error)
        }
        await clearImageCache()
    }

    /// 탈퇴 API는 서버 계정만 지운다 — **로컬 토큰은 여기서 지워야 한다.**
    /// 안 지우면 탈퇴 후에도 죽은 토큰이 Keychain에 남아 다음 실행에서 401을 맞는다.
    func deleteAccount() async throws {
        await pushToken.clear()
        do {
            try await userRepository.deleteAccount()
        } catch {
            await pushToken.restore()
            throw SettingError(accountError: error)
        }
        // 서버 계정이 사라진 뒤라 토큰 삭제 실패는 되돌릴 수 없다.
        // 다음 실행의 프로필 조회가 401을 받아 로그인 화면으로 보내므로 여기서는 무시한다.
        try? tokenStore.clear()
        await clearImageCache()
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
