import Foundation
import SettingDomain

/// 데모용 프로필 공급자.
///
/// 실제 조회는 이슈 #33의 `UserRepository`가 맡는다. 그게 머지되면 이 타입을 지우고,
/// `UserRepository`를 `SettingProfileProvider`에 맞춰주는 어댑터를 `CompositionRoot`에 두면 된다.
struct StubProfileProvider: SettingProfileProvider {

    /// 시안에 실려 있는 값 그대로 — 시안 대조 검증이 문구까지 비교한다.
    ///
    /// `static`인 이유: 계정 관리 화면으로 바로 진입할 때는 부모 스냅샷이 아직 없어서
    /// 데모가 `AccountFeature.State.profile`에 직접 넣어야 한다. 같은 값을 두 번 적지 않는다.
    static let profile = SettingProfile(
        nickname: "나는야멋쟁이토마토",
        // 프로필 이미지 표시를 확인하기 위한 샘플.
        avatarURL: URL(string: "https://picsum.photos/seed/challa-profile/200")
    )

    func fetchProfile() async throws -> SettingProfile {
        Self.profile
    }
}
