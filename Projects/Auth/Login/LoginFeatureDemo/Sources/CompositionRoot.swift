import AuthData // 앱 조립 지점이라 Data를 직접 import 한다 (아키텍처 규칙 2의 예외)
import AuthDomain
import CHALLANetwork
import ComposableArchitecture
import Foundation
import Keychain

/// live 의존성 조립 지점 — 데모앱에서 유일하게 Data 구현체를 생성하는 곳.
///
/// ⚠️ `App/CHALLAApp/Sources/CompositionRoot.swift`가 같은 배선을 갖는다.
///    어댑터 구성을 바꿀 때는 두 파일을 함께 고쳐야 한다.
enum CompositionRoot {

    static func registerLiveDependencies(into values: inout DependencyValues) {
        let tokenStore = KeychainTokenStore(keychain: KeychainStore(service: "com.challa.auth"))

        let client = DefaultHTTPClient(
            session: .shared,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenStore), // login/refresh는 .none이라 미부착
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
