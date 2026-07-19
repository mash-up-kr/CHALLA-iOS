import Foundation
import CHALLANetwork

/// 데모용 토큰 공급자. 실제 앱에서는 `AuthData`가 Keychain을 읽어 구현한다.
struct DemoTokenProvider: TokenProvider {
    let token: String?
    func accessToken() async -> String? { token }
}
