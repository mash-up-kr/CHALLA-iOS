import Dependencies
import DependenciesMacros

// 촬영 진입 버튼이 쓰는 카메라 권한 UseCase 2종.
//
// `liveValue`가 없는 이유는 `FetchCameraFiltersUseCase` 주석 참고.

// MARK: - 권한 요청

/// 카메라 접근을 요청하고 허용 여부를 돌려준다. 촬영 화면으로 넘어갈지 판단하는 근거다.
@DependencyClient
public struct RequestCameraPermissionUseCase: Sendable {
    /// 거절도 정상 결과라 실패 개념이 없다 — 던지지 않는다.
    public var run: @Sendable () async -> Bool = { false }
}

extension RequestCameraPermissionUseCase: TestDependencyKey {

    public static func live(permission: any CameraPermissionProvider) -> RequestCameraPermissionUseCase {
        RequestCameraPermissionUseCase(run: { await permission.requestAccess() })
    }

    public static let testValue = RequestCameraPermissionUseCase()

    public static let previewValue = RequestCameraPermissionUseCase(run: { true })
}

public extension DependencyValues {
    var requestCameraPermissionUseCase: RequestCameraPermissionUseCase {
        get { self[RequestCameraPermissionUseCase.self] }
        set { self[RequestCameraPermissionUseCase.self] = newValue }
    }
}

// MARK: - 설정 앱 열기

/// 카메라 권한을 거절한 사용자를 설정 앱으로 보낸다. 열지 못해도 알리지 않는다.
@DependencyClient
public struct OpenCameraSettingsUseCase: Sendable {
    public var run: @Sendable () async -> Void
}

extension OpenCameraSettingsUseCase: TestDependencyKey {

    public static func live(permission: any CameraPermissionProvider) -> OpenCameraSettingsUseCase {
        OpenCameraSettingsUseCase(run: { await permission.openSystemSettings() })
    }

    public static let testValue = OpenCameraSettingsUseCase()

    public static let previewValue = OpenCameraSettingsUseCase(run: {})
}

public extension DependencyValues {
    var openCameraSettingsUseCase: OpenCameraSettingsUseCase {
        get { self[OpenCameraSettingsUseCase.self] }
        set { self[OpenCameraSettingsUseCase.self] = newValue }
    }
}
