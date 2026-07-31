import Foundation
import SettingDomain

/// 데모용 프로필 공급자.
///
/// 실제 조회는 이슈 #33의 `UserRepository`가 맡는다. 그게 머지되면 이 타입을 지우고,
/// `UserRepository`를 `SettingProfileProvider`에 맞춰주는 어댑터를 `CompositionRoot`에 두면 된다.
struct StubProfileProvider: SettingProfileProvider {

    /// 시안에 실려 있는 값 그대로 — 시안 대조 검증이 문구까지 비교한다.
    private let profile = SettingProfile(
        nickname: "나는야멋쟁이토마토",
        email: "juy***@naver,com",
        avatarURL: nil
    )

    func fetchProfile() async throws -> SettingProfile {
        profile
    }
}
