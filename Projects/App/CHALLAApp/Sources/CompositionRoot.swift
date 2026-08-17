import AuthData
import AuthDomain
import CHALLANetwork
import ComposableArchitecture
import FirebaseMessaging // 델리게이트 콜백 전에도 이미 발급된 토큰을 물어볼 수 있다
import Foundation
import Keychain
import NotificationData
import RoomData
import RoomDomain
import SettingData
import SettingDomain
import UIKit // registerForRemoteNotifications — 권한 허용 직후 FCM 토큰 발급을 건다
import UserData
import UserDomain

/// live 의존성 조립 지점 — 앱에서 유일하게 Data 구현체를 생성하는 곳.
///
/// 등록은 화면이 아니라 aggregate(Domain·Data 쌍) 단위로 나눈다 — 새 aggregate가 생겨도 서로의 작업이 겹치지 않는다.
///
/// `LoginFeatureDemo/Sources/CompositionRoot.swift`가 같은 배선을 갖는다.
enum CompositionRoot {

    static func registerLiveDependencies(
        into values: inout DependencyValues,
        clearImageCache: @escaping @Sendable () async -> Void = {}
    ) {
        // 인터셉터(요청 시 토큰 읽기)와 UseCase(로그인 시 토큰 저장)가 같은 인스턴스를 공유해야 한다.
        let tokenStore = KeychainTokenStore(keychain: KeychainStore(service: "com.challa.auth"))

        let client = DefaultHTTPClient(
            session: .shared,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenStore),
                LoggingInterceptor(level: .basic)
            ]
        )

        let userRepository = DefaultUserRepository(client: client)
        let settings = DefaultSettingsRepository()
        // 알림 토글이 이 인스턴스를 통해 토큰을 등록·해제한다 — 설정보다 먼저 만들어야 한다.
        let pushSynchronizer = PushTokenSynchronizer(
            repository: DefaultPushTokenRepository(client: client),
            isServiceNotificationEnabled: { await settings.fetchNotificationSetting().isServiceEnabled },
            currentToken: { try? await Messaging.messaging().token() }
        )
        values.pushTokenSynchronizer = pushSynchronizer

        // 로그아웃은 계정 관리 어댑터도 쓴다. 값을 돌려받아 넘기는 이유는 registerAuth 주석 참고.
        let logout = registerAuth(into: &values, client: client, tokenStore: tokenStore)
        registerUser(into: &values, client: client, repository: userRepository)
        registerRoom(into: &values, client: client)
        registerSetting(
            into: &values,
            using: SettingCollaborators(
                settings: settings,
                logout: logout,
                userRepository: userRepository,
                tokenStore: tokenStore,
                pushSynchronizer: pushSynchronizer,
                clearImageCache: clearImageCache
            )
        )
    }

    /// 만든 `LogoutUseCase`를 돌려준다 — 뒤에서 `values.logoutUseCase`를 되읽으면
    /// 호출 순서에 묶이면서 그 의존이 시그니처에 드러나지 않는다.
    /// 순서를 바꾸면 미구현 `testValue`가 잡혀 로그아웃이 조용히 실패한다.
    @discardableResult
    private static func registerAuth(
        into values: inout DependencyValues,
        client: any HTTPClient,
        tokenStore: any TokenStore
    ) -> LogoutUseCase {
        let repository = DefaultAuthRepository(client: client)
        let social = DefaultSocialLoginService()
        let logout = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        values.loginUseCase = .live(social: social, repository: repository, tokenStore: tokenStore)
        values.logoutUseCase = logout
        values.refreshTokenUseCase = .live(repository: repository, tokenStore: tokenStore)
        return logout
    }

    /// client는 Auth와 같은 인스턴스여야 한다 — 다른 걸 넘기면 `AuthInterceptor`가 붙인 토큰이 실리지 않아 401이 난다.
    private static func registerUser(
        into values: inout DependencyValues,
        client: any HTTPClient,
        repository: any UserRepository
    ) {
        let imageUploader = DefaultProfileImageUploader(client: client)

        values.fetchMyProfileUseCase = .live(repository: repository)
        values.setupProfileUseCase = .live(repository: repository, uploader: imageUploader)
    }

    /// client 공유 조건은 registerUser와 같다. 데모앱은 이 자리에 `InMemoryRoomRepository`를 꽂는다.
    private static func registerRoom(into values: inout DependencyValues, client: any HTTPClient) {
        let repository = DefaultRoomRepository(client: client)

        values.fetchRoomsUseCase = .live(repository: repository)
        values.createRoomUseCase = .live(repository: repository)
        values.joinRoomUseCase = .live(repository: repository)
        values.fetchRoomDetailUseCase = .live(repository: repository)

        // 방 상세의 사진 그리드가 쓰는 fetchRoomPhotosUseCase는 등록하지 않는다 —
        // 실서버 구현(PhotoData)이 아직 없다. 미등록 상태로 두면 호출 시 런타임 경고가 뜨고
        // 그리드는 빈 칸으로 남는다. 구현이 생기면 여기서 등록한다.
    }

    /// 설정 조립이 필요로 하는 다른 aggregate의 결과물.
    /// 설정 화면 하나가 Auth·User·Notification을 모두 걸치기 때문에 인자가 많아 묶었다.
    private struct SettingCollaborators {
        let settings: any SettingsRepository
        let logout: LogoutUseCase
        let userRepository: any UserRepository
        let tokenStore: any TokenStore
        let pushSynchronizer: PushTokenSynchronizer
        let clearImageCache: @Sendable () async -> Void
    }

    /// 테마·알림은 기기에 저장하고, 프로필·계정은 다른 aggregate를 어댑터로 잇는다
    /// (`Sources/Adapters/` 두 파일의 주석 참고).
    private static func registerSetting(
        into values: inout DependencyValues,
        using collaborators: SettingCollaborators
    ) {
        let settings = collaborators.settings
        let userRepository = collaborators.userRepository
        let pushSynchronizer = collaborators.pushSynchronizer
        let permission = SystemNotificationPermissionProvider()
        let profile = SettingProfileProviderAdapter(repository: userRepository)
        let account = AccountRepositoryAdapter(
            logout: collaborators.logout,
            userRepository: userRepository,
            tokenStore: collaborators.tokenStore,
            pushToken: AccountRepositoryAdapter.PushTokenControl(
                clear: { await pushSynchronizer.clear() },
                restore: { await pushSynchronizer.sync() }
            ),
            clearImageCache: collaborators.clearImageCache
        )

        values.loadProfileUseCase = .live(profile: profile)
        values.loadThemeUseCase = .live(settings: settings)
        values.selectThemeUseCase = .live(settings: settings)
        values.loadNotificationSettingsUseCase = .live(settings: settings, permission: permission)
        values.openSystemNotificationSettingsUseCase = .live(permission: permission)
        values.signOutUseCase = .live(account: account)
        values.deleteAccountUseCase = .live(account: account)

        // 토글은 값을 저장한 뒤 토큰 등록·해제 API까지 부른다 (`PushTokenSynchronizer` 참고).
        // 이 이펙트는 알림 화면에 묶여 있어서, 토글하고 바로 뒤로 가면 취소된다.
        // 그래서 서버 호출만 `Task`로 떼어내 화면과 무관하게 끝나게 한다.
        values.updateServiceNotificationUseCase = UpdateServiceNotificationUseCase(run: { isEnabled in
            await settings.updateNotificationSetting(NotificationSetting(isServiceEnabled: isEnabled))
            Task { await pushSynchronizer.sync() }
        })

        // 권한을 허용받으면 곧바로 원격 알림에 등록해야 FCM 토큰이 발급된다.
        values.requestNotificationAuthorizationUseCase = RequestNotificationAuthorizationUseCase(run: {
            let status = await permission.requestAuthorization()
            if status == .authorized {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            return status
        })
    }
}
