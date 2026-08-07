import AuthData
import AuthDomain
import CHALLANetwork
import ComposableArchitecture
import Foundation
import Keychain
import UserData
import UserDomain

/// live 의존성 조립 지점 — 앱에서 유일하게 Data 구현체를 생성하는 곳.
///
/// 등록은 화면이 아니라 aggregate(Domain·Data 쌍) 단위로 나눈다 — 새 aggregate가 생겨도 서로의 작업이 겹치지 않는다.
///
/// `LoginFeatureDemo/Sources/CompositionRoot.swift`가 같은 배선을 갖는다.
enum CompositionRoot {

    static func registerLiveDependencies(into values: inout DependencyValues) {
        // 인터셉터(요청 시 토큰 읽기)와 UseCase(로그인 시 토큰 저장)가 같은 인스턴스를 공유해야 한다.
        let tokenStore = KeychainTokenStore(keychain: KeychainStore(service: "com.challa.auth"))

        let client = DefaultHTTPClient(
            session: .shared,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenStore),
                LoggingInterceptor(level: .basic)
            ]
        )

        registerAuth(into: &values, client: client, tokenStore: tokenStore)
        registerUser(into: &values, client: client)
    }

    private static func registerAuth(
        into values: inout DependencyValues,
        client: any HTTPClient,
        tokenStore: any TokenStore
    ) {
        let repository = DefaultAuthRepository(client: client)
        let social = DefaultSocialLoginService()

        values.loginUseCase = .live(social: social, repository: repository, tokenStore: tokenStore)
        values.logoutUseCase = .live(repository: repository, tokenStore: tokenStore)
        values.refreshTokenUseCase = .live(repository: repository, tokenStore: tokenStore)
    }

    /// client는 Auth와 같은 인스턴스여야 한다 — 다른 걸 넘기면 `AuthInterceptor`가 붙인 토큰이 실리지 않아 401이 난다.
    private static func registerUser(into values: inout DependencyValues, client: any HTTPClient) {
        let repository = DefaultUserRepository(client: client)
        let imageUploader = DefaultProfileImageUploader(client: client)

        values.fetchMyProfileUseCase = .live(repository: repository)
        values.setupProfileUseCase = .live(repository: repository, uploader: imageUploader)
    }
}
