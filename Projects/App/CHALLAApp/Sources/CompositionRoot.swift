import AuthData
import AuthDomain
import CHALLANetwork
import ComposableArchitecture
import Foundation
import Keychain

/// live 의존성 조립 지점 — 앱에서 유일하게 Data 구현체를 생성하는 곳.
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

        let repository = DefaultAuthRepository(client: client)
        let social = DefaultSocialLoginService()

        values.loginUseCase = .live(social: social, repository: repository, tokenStore: tokenStore)
        values.logoutUseCase = .live(repository: repository, tokenStore: tokenStore)
        values.refreshTokenUseCase = .live(repository: repository, tokenStore: tokenStore)
    }
}
