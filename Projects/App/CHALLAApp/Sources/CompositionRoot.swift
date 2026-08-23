import AuthData
import AuthDomain
import CameraFeature // CameraFilterCatalog — 진입 전에 LUT를 등록해 둔다
import CHALLANetwork
import ComposableArchitecture
import FirebaseMessaging // 델리게이트 콜백 전에도 이미 발급된 토큰을 물어볼 수 있다
import Foundation
import Keychain
import NotificationData
import PhotoData
import PhotoDomain
import PhotoLibrary
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

    #if DEBUG
        private static let loggingLevel: LoggingInterceptor.Level = .verbose
    #else
        private static let loggingLevel: LoggingInterceptor.Level = .basic
    #endif

    static func registerLiveDependencies(
        into values: inout DependencyValues,
        clearImageCache: @escaping @Sendable () async -> Void = {}
    ) {
        // 인터셉터(요청 시 토큰 읽기)와 UseCase(로그인 시 토큰 저장)가 같은 인스턴스를 공유해야 한다.
        let tokenStore = KeychainTokenStore(keychain: KeychainStore(service: "com.challa.auth"))
        let sessionExpiration = SessionExpirationChannel()
        values.sessionExpirationChannel = sessionExpiration

        let refreshTokenUseCase = makeRefreshTokenUseCase(tokenStore: tokenStore)
        let client = makeClient(
            tokenStore: tokenStore,
            refreshTokenUseCase: refreshTokenUseCase,
            sessionExpiration: sessionExpiration
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
        let logout = registerAuth(
            into: &values,
            client: client,
            tokenStore: tokenStore,
            refreshTokenUseCase: refreshTokenUseCase
        )
        registerUser(into: &values, client: client, repository: userRepository)
        registerRoom(into: &values, client: client)
        registerPhoto(into: &values, client: client)
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

    /// 갱신 전용 클라이언트에 얹는다 — 인증 헤더도 재시도도 붙이지 않는다.
    /// 갱신 요청의 401이 다시 갱신을 부르는 재귀에 빠지지 않도록 파이프라인을 갈라 둔다.
    private static func makeRefreshTokenUseCase(tokenStore: any TokenStore) -> RefreshTokenUseCase {
        .live(
            repository: DefaultAuthRepository(
                client: DefaultHTTPClient(
                    session: .shared,
                    interceptors: [LoggingInterceptor(level: loggingLevel)]
                )
            ),
            tokenStore: tokenStore
        )
    }

    /// 모든 도메인이 공유하는 요청 클라이언트. 401을 만나면 토큰을 갱신하고 그 요청을 한 번 다시 보낸다.
    private static func makeClient(
        tokenStore: KeychainTokenStore,
        refreshTokenUseCase: RefreshTokenUseCase,
        sessionExpiration: SessionExpirationChannel
    ) -> any HTTPClient {
        let refresher = AuthTokenRefresher(
            refresh: { try await refreshTokenUseCase.run() },
            tokenStore: tokenStore,
            onSessionExpired: { sessionExpiration.notify() }
        )

        return DefaultHTTPClient(
            session: .shared,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenStore),
                // 응답 본문 확인은 개발 중에만 — 릴리스 로그에 토큰·PII를 남기지 않는다.
                LoggingInterceptor(level: Self.loggingLevel)
            ],
            retrier: TokenRefreshRetrier(refresher: refresher)
        )
    }

    /// 만든 `LogoutUseCase`를 돌려준다 — 뒤에서 `values.logoutUseCase`를 되읽으면
    /// 호출 순서에 묶이면서 그 의존이 시그니처에 드러나지 않는다.
    /// 순서를 바꾸면 미구현 `testValue`가 잡혀 로그아웃이 조용히 실패한다.
    @discardableResult
    private static func registerAuth(
        into values: inout DependencyValues,
        client: any HTTPClient,
        tokenStore: any TokenStore,
        refreshTokenUseCase: RefreshTokenUseCase
    ) -> LogoutUseCase {
        let repository = DefaultAuthRepository(client: client)
        let social = DefaultSocialLoginService()
        let logout = LogoutUseCase.live(repository: repository, tokenStore: tokenStore)

        values.loginUseCase = .live(social: social, repository: repository, tokenStore: tokenStore)
        values.logoutUseCase = logout
        values.refreshTokenUseCase = refreshTokenUseCase // 401 재시도 경로와 같은 갱신 클라이언트를 공유한다
        values.restoreSessionUseCase = .live(
            tokenStore: tokenStore,
            launchState: UserDefaultsLaunchStateStore()
        )
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
        values.fetchShootableRoomsUseCase = .live(repository: repository)

        // 방 상세·사진 상세가 쓰는 fetchRoomPhotosUseCase는 Photo aggregate라 registerPhoto에서 등록한다.
    }

    /// client 공유 조건은 registerUser와 같다. 카메라 화면이 앱에 조립되면 이 배선을 그대로 쓴다.
    private static func registerPhoto(into values: inout DependencyValues, client: any HTTPClient) {
        let photoRepository = DefaultPhotoRepository(client: client)
        let filterRepository = DefaultCameraFilterRepository(client: client)
        let uploader = DefaultPhotoUploader(client: client)
        // 안내 노출 기록만 서버가 아니라 기기에 남는다 (`CameraOnboardingRepository` 주석 참고).
        let onboarding = DefaultCameraOnboardingRepository()
        let cameraPermission = SystemCameraPermissionProvider()

        // 사진 조회·리액션·저장 — 방 상세 그리드와 사진 상세가 함께 쓴다.
        values.fetchRoomPhotosUseCase = .live(repository: photoRepository)
        // 리액션은 목록에 없어 사진을 펼칠 때 한 장씩 지연 조회한다(1+N 회피).
        values.fetchPhotoReactionsUseCase = .live(repository: photoRepository)
        values.setPhotoReactionUseCase = .live(repository: photoRepository)
        values.savePhotoUseCase = .live(repository: photoRepository, photoLibrary: PhotoLibraryWritingAdapter())

        values.fetchCameraFiltersUseCase = .live(repository: filterRepository)
        values.prepareCameraFiltersUseCase = .live(
            repository: filterRepository,
            register: CameraFilterCatalog.register(cubeData:for:)
        )
        values.uploadPhotoUseCase = .live(uploader: uploader)
        values.shouldShowCameraCoachMarkUseCase = .live(repository: onboarding)
        values.markCameraCoachMarkSeenUseCase = .live(repository: onboarding)
        values.requestCameraPermissionUseCase = .live(permission: cameraPermission)
        values.openCameraSettingsUseCase = .live(permission: cameraPermission)
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

    /// 알림은 기기에 저장하고, 프로필·계정은 다른 aggregate를 어댑터로 잇는다
    /// (`Sources/Adapters/` 두 파일의 주석 참고).
    /// 테마는 여기 없다 — `@Shared(.appTheme)`가 저장소와 직접 이어져 있어 조립할 것이 없다.
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

/// Core의 사진첩 저장(`PhotoLibraryStore`)을 도메인 인터페이스(`PhotoLibraryWriting`)에 연결한다.
/// Core는 도메인을 모르므로(`Keychain`과 같은 이유) 앱에서 어댑터로 오류를 `PhotoError`로 바꿔 준다.
private struct PhotoLibraryWritingAdapter: PhotoLibraryWriting {

    private let store = PhotoLibraryStore()

    func save(imageData: Data) async throws {
        do {
            try await store.save(imageData: imageData)
        } catch PhotoLibraryError.permissionDenied {
            throw PhotoError.permissionDenied
        } catch {
            throw PhotoError.saveFailed
        }
    }
}
