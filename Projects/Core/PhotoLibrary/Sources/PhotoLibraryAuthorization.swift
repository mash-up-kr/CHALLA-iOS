import Photos

/// 사진 라이브러리 접근 권한 상태.
/// `PHAuthorizationStatus`를 옮겨 담아 상위 레이어가 Photos 프레임워크를 모른 채 분기할 수 있게 한다.
public enum PhotoLibraryAuthorization: Sendable, Equatable {
    case authorized
    /// 사용자가 고른 일부 사진만 허용 (iOS 14+).
    case limited
    case denied
    /// 기기 정책(스크린타임 등)으로 차단 — 사용자가 설정에서 풀 수 없다.
    case restricted
    case notDetermined

    /// 사진을 고를 수 있는 상태인지. `limited`도 피커는 정상 동작한다.
    public var allowsPicking: Bool {
        self == .authorized || self == .limited
    }
}

extension PhotoLibraryAuthorization {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .limited: self = .limited
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .denied // 모르는 상태는 막는 쪽으로 떨어뜨린다
        }
    }
}
