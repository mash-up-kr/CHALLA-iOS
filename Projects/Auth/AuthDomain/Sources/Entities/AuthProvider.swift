import Foundation

/// 지원하는 소셜 로그인 제공자.
public enum AuthProvider: String, Sendable, Equatable, CaseIterable {
    case kakao
    case apple
}
