import Dependencies
import DependenciesMacros

// 알림 설정 화면이 쓰는 UseCase 3종.

// MARK: - 불러오기

/// 저장된 알림 설정과 시스템 권한 상태를 한 번에 읽는다.
@DependencyClient
public struct LoadNotificationSettingsUseCase: Sendable {
    /// 저장값도 권한도 실패 개념이 없다 — 던지지 않는다.
    public var run: @Sendable () async -> NotificationSettingsSnapshot = {
        NotificationSettingsSnapshot(setting: .default, authorization: .notDetermined)
    }
}

extension LoadNotificationSettingsUseCase: TestDependencyKey {

    public static func live(
        settings: any SettingsRepository,
        permission: any NotificationPermissionProvider
    ) -> LoadNotificationSettingsUseCase {
        LoadNotificationSettingsUseCase(run: {
            // 둘 다 즉시 돌아오는 로컬 호출이라 병렬로 묶지 않는다.
            let setting = await settings.fetchNotificationSetting()
            let authorization = await permission.authorizationStatus()
            return NotificationSettingsSnapshot(setting: setting, authorization: authorization)
        })
    }

    public static let testValue = LoadNotificationSettingsUseCase()

    public static let previewValue = LoadNotificationSettingsUseCase(run: {
        NotificationSettingsSnapshot(setting: .default, authorization: .denied)
    })
}

public extension DependencyValues {
    var loadNotificationSettingsUseCase: LoadNotificationSettingsUseCase {
        get { self[LoadNotificationSettingsUseCase.self] }
        set { self[LoadNotificationSettingsUseCase.self] = newValue }
    }
}

// MARK: - 서비스 알림 토글

/// 서비스 알림 수신 여부를 저장한다.
///
/// `NotificationSetting` 전체가 아니라 `Bool`을 받는 이유: 지금 항목이 하나뿐이라
/// 화면이 다른 필드를 알 필요가 없다. 항목이 늘면 `(NotificationSetting) async -> Void`로 넓힌다.
@DependencyClient
public struct UpdateServiceNotificationUseCase: Sendable {
    public var run: @Sendable (Bool) async -> Void
}

extension UpdateServiceNotificationUseCase: TestDependencyKey {

    public static func live(settings: any SettingsRepository) -> UpdateServiceNotificationUseCase {
        UpdateServiceNotificationUseCase(run: { isEnabled in
            await settings.updateNotificationSetting(NotificationSetting(isServiceEnabled: isEnabled))
        })
    }

    public static let testValue = UpdateServiceNotificationUseCase()

    public static let previewValue = UpdateServiceNotificationUseCase(run: { _ in })
}

public extension DependencyValues {
    var updateServiceNotificationUseCase: UpdateServiceNotificationUseCase {
        get { self[UpdateServiceNotificationUseCase.self] }
        set { self[UpdateServiceNotificationUseCase.self] = newValue }
    }
}

// MARK: - 설정 앱 열기

/// iOS 설정 앱의 이 앱 화면을 연다 (알림 권한 배너를 눌렀을 때).
///
/// 열지 못해도 알리지 않는다 — 시안에 실패 문구가 없다.
@DependencyClient
public struct OpenSystemNotificationSettingsUseCase: Sendable {
    public var run: @Sendable () async -> Void
}

extension OpenSystemNotificationSettingsUseCase: TestDependencyKey {

    public static func live(
        permission: any NotificationPermissionProvider
    ) -> OpenSystemNotificationSettingsUseCase {
        OpenSystemNotificationSettingsUseCase(run: {
            await permission.openSystemNotificationSettings()
        })
    }

    public static let testValue = OpenSystemNotificationSettingsUseCase()

    public static let previewValue = OpenSystemNotificationSettingsUseCase(run: {})
}

public extension DependencyValues {
    var openSystemNotificationSettingsUseCase: OpenSystemNotificationSettingsUseCase {
        get { self[OpenSystemNotificationSettingsUseCase.self] }
        set { self[OpenSystemNotificationSettingsUseCase.self] = newValue }
    }
}
