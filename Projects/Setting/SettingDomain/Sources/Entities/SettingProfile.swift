import Foundation

/// 설정 화면 헤더에 표시하는 사용자 정보.
///
/// **임시 모델이다.** 프로필의 정본은 이슈 #33이 만드는 `UserProfile`이며,
/// 그게 머지되면 이 타입은 지우고 `UserProfile`을 그대로 쓴다.
/// 지금 #33에 의존을 걸면 설정 화면 전체가 그 이슈에 막히므로 표시에 필요한 최소 필드만 여기 둔다.
public struct SettingProfile: Sendable, Equatable {

    public let nickname: String

    /// 시안에 `hap****@naver.com`처럼 마스킹된 형태로 나온다.
    /// 마스킹 주체가 서버인지 클라이언트인지 정해지지 않아, 받은 문자열을 그대로 표시한다.
    public let email: String

    /// `nil`이면 기본 아바타(회색 실루엣)를 그린다.
    public let avatarURL: URL?

    public init(nickname: String, email: String, avatarURL: URL?) {
        self.nickname = nickname
        self.email = email
        self.avatarURL = avatarURL
    }
}
