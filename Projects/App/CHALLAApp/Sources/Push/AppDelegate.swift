import Dependencies
import FirebaseCore
import FirebaseMessaging
import os
import UIKit
import UserNotifications

/// 푸시 등록 실패는 재현하기 어려워 로그가 유일한 단서다.
/// `print`는 릴리스 빌드에서 남지 않아 사용자 기기에서 꺼내올 수 없다.
private let pushLogger = Logger(subsystem: "com.challa.app", category: "push")

/// 앱이 시작되면 Firebase를 초기화하고 APNs에 등록해, 받은 APNs 토큰을 FCM에 넘겨 FCM 토큰을 발급받는다.
/// 발급된 토큰과 수신한 알림은 델리게이트 콜백으로 오는데 SwiftUI에 같은 기능이 없어 이 클래스가 받는다.
///
/// `UIApplicationDelegate`는 MainActor지만 FCM·알림 델리게이트는 아니라서 그쪽 메서드를 `nonisolated`로 둔다.
/// 그러면 저장 프로퍼티에 접근할 수 없어 동기화 객체는 필요할 때마다 `@Dependency`로 꺼낸다.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // 권한이 이미 허용돼 있으면 여기서 APNs 등록이 걸려 FCM 토큰이 발급된다.
        // 권한이 없으면 조용히 무시되고, 설정 화면에서 허용한 뒤 다시 등록된다.
        application.registerForRemoteNotifications()

        // 지난 실행에서 실패한 등록·해제를 저장값 기준으로 되맞춘다.
        Task {
            @Dependency(\.pushTokenSynchronizer) var synchronizer
            await synchronizer.sync()
        }
        return true
    }

    /// APNs 토큰을 FCM에 넘긴다. 이걸 빠뜨리면 FCM 토큰이 발급되지 않는다.
    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // 시뮬레이터·네트워크 문제로 흔히 실패한다. 알릴 자리가 없어 로그만 남긴다.
        pushLogger.error("원격 알림 등록 실패: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    /// 최초 발급과 갱신 모두 여기로 온다 — 토큰이 바뀌면 서버 등록도 따라가야 한다.
    nonisolated func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            @Dependency(\.pushTokenSynchronizer) var synchronizer
            await synchronizer.tokenReceived(fcmToken)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// 앱을 보고 있을 때 온 알림. 이 델리게이트가 없으면 화면에 아무 것도 뜨지 않는다.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    // TODO: 알림을 탭했을 때 해당 방·사진으로 보내는 딥링크 — 대상 화면이 생기면 추가한다.
}
