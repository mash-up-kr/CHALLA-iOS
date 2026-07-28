import CHALLANetwork
import Foundation

/// 고정 토큰(또는 nil)을 돌려주는 테스트용 TokenProvider.
struct FakeTokenProvider: TokenProvider {
    let token: String?
    func accessToken() async -> String? {
        token
    }
}
