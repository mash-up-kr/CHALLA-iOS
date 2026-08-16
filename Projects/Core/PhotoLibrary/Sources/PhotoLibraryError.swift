import Foundation

/// 사진첩 저장 실패 원인.
public enum PhotoLibraryError: Error, Equatable, Sendable {

    /// 사용자가 사진 추가 권한을 거부함 (또는 기기 정책으로 막힘).
    case permissionDenied

    /// 권한은 있으나 사진첩 쓰기가 실패함.
    case saveFailed
}
