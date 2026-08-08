import SettingDomain
import UserDomain

/// `SettingProfileProvider` 구현 — 설정 헤더용 프로필을 `UserRepository`에서 가져온다.
///
/// **여기 있는 이유** — `SettingProfileProvider`는 `SettingDomain`이 모양만 정의하고
/// 구현을 `SettingData`에 두지 않는다. 프로필의 정본은 다른 aggregate(`UserRepository`)라
/// 설정 쪽에서 또 구현하면 같은 서버 계약이 두 곳에 생긴다.
/// 두 Domain을 다 아는 곳은 조립 지점뿐이라 App이 맡는다.
struct SettingProfileProviderAdapter: SettingProfileProvider {

    private let repository: any UserRepository

    init(repository: any UserRepository) {
        self.repository = repository
    }

    func fetchProfile() async throws -> SettingProfile {
        do {
            let profile = try await repository.fetchMyProfile()
            // 닉네임은 프로필 설정을 마쳐야 생긴다. 설정 화면에 닿았다면 이미 마친 상태다.
            return SettingProfile(nickname: profile.nickname ?? "", avatarURL: profile.imageURL)
        } catch is CancellationError {
            throw CancellationError() // 화면 이탈은 실패가 아니라 그대로 올린다
        } catch {
            throw SettingError(userError: error)
        }
    }
}

extension SettingError {

    /// `UserError` → `SettingError` 매핑.
    /// `.server`까지 `.profileUnavailable`로 접는 이유: 설정 화면은 서버 문구를 띄울 자리가 없고
    /// 헤더가 비었다는 사실만 알리면 된다.
    init(userError error: any Error) {
        switch error {
        case UserError.network:
            self = .network
        case UserError.unauthorized, UserError.server:
            self = .profileUnavailable
        default:
            self = .unknown
        }
    }
}
