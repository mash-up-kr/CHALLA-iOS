import Foundation

/// STOMP 연결·구독 과정에서 발생하는 오류.
///
/// Data 레이어는 이 오류를 잡아 도메인 오류(`ChatError` 등)로 매핑한다.
/// Feature·Domain은 이 타입의 존재를 모른다 (아키텍처 규칙 6).
public enum STOMPError: Error, Equatable {

    /// 프레임 형식이 STOMP 1.2에 맞지 않는다. 읽기 루프는 그 메시지만 버리고 연결은 유지한다.
    case malformedFrame(reason: String)

    /// 소켓은 열렸지만 서버가 CONNECTED를 보내지 않았다.
    case connectTimeout

    /// 서버가 ERROR 프레임으로 응답했다.
    case server(message: String)

    /// 토큰이 거절됐고 갱신도 실패했다. 재연결을 멈춘다.
    case unauthorized

    /// 연결이 끊긴 상태에서 전송을 시도했다.
    case notConnected
}

extension STOMPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .malformedFrame(reason): "STOMP 프레임을 해석할 수 없습니다: \(reason)"
        case .connectTimeout: "STOMP 연결 응답이 오지 않았습니다."
        case let .server(message): "서버가 오류를 알렸습니다: \(message)"
        case .unauthorized: "소켓 인증에 실패했습니다."
        case .notConnected: "소켓이 연결돼 있지 않습니다."
        }
    }
}

extension STOMPError {

    /// 프레임 하나가 깨진 것뿐이면 그 메시지만 버리고 연결은 유지한다.
    var isMalformedFrame: Bool {
        if case .malformedFrame = self {
            return true
        }
        return false
    }
}
