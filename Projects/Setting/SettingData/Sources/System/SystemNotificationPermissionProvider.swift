import Foundation
import SettingDomain
import UIKit
import UserNotifications

/// `NotificationPermissionProvider`의 기본 구현 — OS의 알림 권한을 읽고·요청하고 설정 앱을 연다.
///
/// OS를 만지지만 Core가 아니라 여기 있다 (근거: MODULE.md "Core가 아니라 여기 있는 이유").
///
/// 권한을 받은 뒤 원격 알림에 등록하는 일(FCM 토큰 발급)은 여기서 하지 않는다 —
/// 실행 앱의 `CompositionRoot`가 이 구현을 감싸 이어붙인다.
public struct SystemNotificationPermissionProvider: NotificationPermissionProvider {

    /// 시안의 배너 문구가 "앱 알림이 꺼져있어요"라 배너·소리·배지를 한 묶음으로 요청한다.
    private static let requestedOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

    public init() {}

    public func authorizationStatus() async -> NotificationAuthorizationStatus {
        await Self.mapped(rawAuthorizationStatus())
    }

    /// 요청이 던지거나 거절되어도 **다시 읽은 실제 상태**를 돌려준다 —
    /// granted 플래그만 믿으면 `.provisional`처럼 granted가 false인 허용 상태를 놓친다.
    public func requestAuthorization() async -> NotificationAuthorizationStatus {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: Self.requestedOptions)
        } catch {
            // 요청 자체가 실패한 경우도 아래 재조회로 판단한다 (실패 문구가 시안에 없다).
        }
        return await authorizationStatus()
    }

    public func openSystemNotificationSettings() async {
        await openSettingsApp()
    }

    // MARK: - 권한 조회

    /// `UNNotificationSettings`는 `Sendable`이 아니라 그대로 `await` 밖으로 내보낼 수 없다.
    /// 클로저 안에서 `Sendable`인 `UNAuthorizationStatus`만 꺼내 넘긴다.
    private func rawAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// OS 상태 → Domain 상태 매핑. 순수 함수라 시뮬레이터 없이 테스트한다.
    ///
    /// `.provisional`(조용한 알림)·`.ephemeral`(앱 클립)은 `.authorized`로 접는다 —
    /// 배너 문구가 "꺼져있어요"라 알림이 어떤 형태로든 오는 상태에서는 띄우면 안 된다.
    static func mapped(_ status: UNAuthorizationStatus) -> NotificationAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .authorized
        @unknown default:
            // 새 상태가 생기면 알림이 온다고 가정하지 않는다 — 배너를 띄워 사용자가 확인하게 한다.
            .denied
        }
    }

    // MARK: - 설정 앱 열기

    /// `UIApplication`은 메인 액터 격리라 여기서 경계를 넘는다.
    /// 열지 못하면 조용히 무시한다 (인터페이스 계약 — 시안에 실패 문구가 없다).
    @MainActor
    private func openSettingsApp() async {
        // 앱의 *알림* 설정으로 바로 가는 URL을 먼저 시도하고, 열지 못하면 앱 설정 루트로 떨어진다.
        let candidates = [
            UIApplication.openNotificationSettingsURLString,
            UIApplication.openSettingsURLString
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate), UIApplication.shared.canOpenURL(url) else { continue }
            // 열기에 실패해도(false) 다음 후보로 넘어간다 — canOpenURL만으로는 성공이 보장되지 않는다.
            if await UIApplication.shared.open(url) {
                return
            }
        }
    }
}
