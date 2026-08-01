@testable import SettingDomain
import Foundation

/// 테스트용 `SettingsRepository`. 저장된 값을 생성 시점에 주입한다.
///
/// `actor`가 아니라 `final class` + 락 없이 두는 이유: 테스트가 단일 태스크에서
/// 순차로만 호출하므로 경쟁이 없다. 호출 기록만 남긴다.
final class MockSettingsRepository: SettingsRepository, @unchecked Sendable {

    private let storedTheme: AppTheme
    private let storedNotification: NotificationSetting

    private(set) var updatedThemes: [AppTheme] = []
    private(set) var updatedNotifications: [NotificationSetting] = []

    init(
        storedTheme: AppTheme = .default,
        storedNotification: NotificationSetting = .default
    ) {
        self.storedTheme = storedTheme
        self.storedNotification = storedNotification
    }

    func fetchTheme() async -> AppTheme {
        storedTheme
    }

    func updateTheme(_ theme: AppTheme) async {
        updatedThemes.append(theme)
    }

    func fetchNotificationSetting() async -> NotificationSetting {
        storedNotification
    }

    func updateNotificationSetting(_ setting: NotificationSetting) async {
        updatedNotifications.append(setting)
    }
}

/// 테스트용 프로필 공급자.
final class MockProfileProvider: SettingProfileProvider, @unchecked Sendable {

    private let result: Result<SettingProfile, SettingError>
    private(set) var callCount = 0

    init(result: Result<SettingProfile, SettingError> = .success(.stub)) {
        self.result = result
    }

    func fetchProfile() async throws -> SettingProfile {
        callCount += 1
        return try result.get()
    }
}

extension SettingProfile {
    static let stub = SettingProfile(
        nickname: "나는야멋쟁이토마토",
        email: "hap****@naver.com",
        avatarURL: nil
    )
}
