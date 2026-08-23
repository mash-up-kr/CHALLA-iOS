@testable import SettingData
import Foundation
import SettingDomain
import Testing

struct DefaultSettingsRepositoryTests {

    private func makeRepository(
        storage: InMemorySettingsStorage = InMemorySettingsStorage()
    ) -> DefaultSettingsRepository {
        DefaultSettingsRepository(storage: storage)
    }

    // MARK: - 알림

    @Test("설정한 적 없으면 알림 기본값(꺼짐)을 돌려준다")
    func notificationFallsBackToDefault() async {
        let setting = await makeRepository().fetchNotificationSetting()
        #expect(setting == .default)
        #expect(setting.isServiceEnabled == false)
    }

    @Test("켜둔 값과 꺼둔 값을 구분해서 저장한다")
    func notificationRoundTrip() async {
        let repository = makeRepository()

        await repository.updateNotificationSetting(NotificationSetting(isServiceEnabled: true))
        #expect(await repository.fetchNotificationSetting().isServiceEnabled == true)

        await repository.updateNotificationSetting(NotificationSetting(isServiceEnabled: false))
        #expect(await repository.fetchNotificationSetting().isServiceEnabled == false)
    }

    @Test("꺼둔 것과 설정한 적 없는 것을 구분한다 — 둘 다 false로 보이면 기본값 규칙이 무의미해진다")
    func notificationDistinguishesUnsetFromOff() async {
        let storage = InMemorySettingsStorage()
        let repository = makeRepository(storage: storage)

        #expect(storage.bool(forKey: "challa.setting.notification.service") == nil)

        await repository.updateNotificationSetting(NotificationSetting(isServiceEnabled: false))

        #expect(storage.bool(forKey: "challa.setting.notification.service") == false)
    }
}
