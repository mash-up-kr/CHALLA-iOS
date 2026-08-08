import Foundation

/// 설정 화면 헤더에 표시하는 사용자 정보.
///
/// 프로필 원본은 `UserDomain.UserProfile`이다. 다른 모듈이라 여기서 직접 쓰지 않고
/// 화면에 필요한 필드만 복사해 둔다. 값을 옮기는 일은 실행 앱의 `CompositionRoot`가 한다.
public struct SettingProfile: Sendable, Equatable {

    public let nickname: String

    /// `nil`이면 기본 아바타(회색 실루엣)를 그린다.
    public let avatarURL: URL?

    public init(nickname: String, avatarURL: URL?) {
        self.nickname = nickname
        self.avatarURL = avatarURL
    }
}
