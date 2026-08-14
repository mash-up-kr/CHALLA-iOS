import SettingDomain
import UserDomain

/// `SettingProfileProvider` 구현 — 설정 헤더용 프로필을 `UserRepository`에서 가져온다.
///
/// 프로필은 `UserDomain`이 담당해서 `SettingDomain`에서 직접 가져올 수 없다.
/// 둘 다 아는 App이 연결한다.
struct SettingProfileProviderAdapter: SettingProfileProvider {

    private let repository: any UserRepository

    init(repository: any UserRepository) {
        self.repository = repository
    }

    func fetchProfile() async throws -> SettingProfile {
        do {
            let profile = try await repository.fetchMyProfile()
            // 닉네임은 프로필 설정을 마쳐야 생긴다. 설정 화면에 닿았다면 이미 마친 상태다.
            // 전제가 깨지면 헤더에 빈 이름이 조용히 그려지므로 개발 중에는 드러나게 한다.
            assert(profile.isProfileCompleted, "프로필 설정을 마치지 않았는데 설정 화면에 도달했다")
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
