import Foundation

/// 설정 기능이 실패하는 방식. `SettingData` 구현체가 모든 예외를 이 타입으로 정규화해 던진다.
public enum SettingError: Error, Equatable, Sendable {

    /// 서버에 닿지 못했다 (연결 끊김·타임아웃 등).
    case network

    /// 서버는 응답했지만 프로필을 내려주지 못했다.
    case profileUnavailable

    /// 위 어디에도 해당하지 않는 실패.
    case unknown

    /// 사용자에게 보여줄 문구.
    /// TODO: 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
    public var userMessage: String {
        switch self {
        case .network:
            "네트워크 연결을 확인해 주세요."
        case .profileUnavailable:
            "프로필을 불러오지 못했어요."
        case .unknown:
            "잠시 후 다시 시도해 주세요."
        }
    }
}
