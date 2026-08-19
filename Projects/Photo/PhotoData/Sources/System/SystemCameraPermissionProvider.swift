import AVFoundation
import Foundation
import PhotoDomain
import UIKit

/// `CameraPermissionProvider`의 기본 구현 — OS의 카메라 권한을 요청하고 설정 앱을 연다.
///
/// OS를 만지지만 Core가 아니라 여기 있다 (`SystemNotificationPermissionProvider`와 같은 판단).
public struct SystemCameraPermissionProvider: CameraPermissionProvider {

    public init() {}

    public func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            // 거절·제한 상태에서는 시스템 창을 다시 띄울 수 없다 — 호출부가 설정 앱으로 안내한다.
            return false
        }
    }

    public func openSystemSettings() async {
        await openSettingsApp()
    }

    /// `UIApplication`은 메인 액터 격리라 여기서 경계를 넘는다.
    /// 열지 못하면 조용히 무시한다 (인터페이스 계약 — 시안에 실패 문구가 없다).
    @MainActor
    private func openSettingsApp() async {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        await UIApplication.shared.open(url)
    }
}
