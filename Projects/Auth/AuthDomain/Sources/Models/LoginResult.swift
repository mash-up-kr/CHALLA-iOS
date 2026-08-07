import Foundation

/// Feature에 노출하는 로그인 결과.
///
/// 토큰은 `LoginUseCase`가 이미 `TokenStore`에 저장했으므로 감춘다 — Feature는 토큰의 존재를 모른다.
public struct LoginResult: Sendable, Equatable {

    public let isNewUser: Bool

    public init(isNewUser: Bool) {
        self.isNewUser = isNewUser
    }
}
