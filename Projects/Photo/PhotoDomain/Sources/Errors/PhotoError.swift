import Foundation

/// 사진 기능에서 Feature까지 전달되는 도메인 오류.
///
/// Data와 Core 구현이 자기 오류를 이 타입으로 변환해 던진다. Domain은 서버·사진첩 API 오류 타입을 모른다.
public enum PhotoError: Error, Equatable, Sendable {

    /// 오프라인·타임아웃 등 전송 자체가 실패.
    case network

    /// 서버가 실패를 알림.
    case server(message: String)

    /// 사진첩 추가 권한 없음. 설정으로 안내한다.
    case permissionDenied

    /// 권한은 있으나 사진첩에 쓰지 못함.
    case saveFailed

    /// 그 외 분류 불가능한 오류.
    case unknown

    // TODO: 문구는 임의 작성본 — 기획의 에러 문구 가이드가 확정되면 일괄 교체한다.
    /// 얼럿 메시지.
    public var userMessage: String {
        switch self {
        case .network: return "네트워크 연결을 확인해 주세요."
        case let .server(message): return message.isEmpty ? "사진을 불러오지 못했어요." : message
        case .permissionDenied: return "사진첩 접근 권한이 필요해요. 설정에서 허용해 주세요."
        case .saveFailed: return "사진을 저장하지 못했어요."
        case .unknown: return "알 수 없는 오류가 발생했어요."
        }
    }
}
