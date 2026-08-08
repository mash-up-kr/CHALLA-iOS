@testable import SettingDomain
import Testing

struct LoadNotificationSettingsUseCaseTests {

    @Test("저장값과 권한을 하나의 스냅샷으로 합친다")
    func combinesSettingAndAuthorization() async {
        let useCase = LoadNotificationSettingsUseCase.live(
            settings: MockSettingsRepository(
                storedNotification: NotificationSetting(isServiceEnabled: true)
            ),
            permission: MockNotificationPermissionProvider(status: .denied)
        )

        let snapshot = await useCase.run()

        #expect(snapshot.setting.isServiceEnabled == true)
        #expect(snapshot.authorization == .denied)
    }

    @Test(
        "권한 상태를 가공 없이 실어 나른다",
        arguments: [
            NotificationAuthorizationStatus.notDetermined,
            .denied,
            .authorized
        ]
    )
    func passesThroughAuthorization(status: NotificationAuthorizationStatus) async {
        let useCase = LoadNotificationSettingsUseCase.live(
            settings: MockSettingsRepository(),
            permission: MockNotificationPermissionProvider(status: status)
        )

        #expect(await useCase.run().authorization == status)
    }
}

struct UpdateServiceNotificationUseCaseTests {

    @Test("Bool을 NotificationSetting으로 감싸 저장한다", arguments: [true, false])
    func wrapsFlagIntoSetting(isEnabled: Bool) async {
        let repository = MockSettingsRepository()
        let useCase = UpdateServiceNotificationUseCase.live(settings: repository)

        await useCase.run(isEnabled)

        #expect(repository.updatedNotifications == [NotificationSetting(isServiceEnabled: isEnabled)])
    }
}
