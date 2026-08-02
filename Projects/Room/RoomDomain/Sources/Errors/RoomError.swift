/// 방 흐름에서 일어날 수 있는 실패의 목록. Data가 던지고 Feature가 받는다.
///
/// Domain에 두는 이유 — Feature는 Data를 import하지 않고 Data는 Feature를 모르므로,
/// 양쪽이 함께 아는 곳은 Domain뿐이다. 성공 타입(`Room`)이 여기 있으니 실패 타입도
/// 여기 있어야 시그니처의 짝이 맞는다.
///
/// Data는 서버·저장소 오류를 반드시 이 타입으로 번역해 던진다. 그래야 HTTP 상태 코드
/// 같은 서버 사정이 Data에서 끊기고 Feature는 방 이야기만 알게 된다.
/// `AuthError`와 달리 `.cancelled`가 없다 — 방 흐름에는 사용자가 취소하는 외부 SDK 왕복이 없다.
public enum RoomError: Error, Equatable, Sendable {
    case network                    // 오프라인·타임아웃
    case unauthorized               // 401 — 토큰 만료
    case invalidRoomName            // 빈 이름으로 생성 시도 (UseCase 경계 방어)
    case invalidInviteCode          // 코드가 비었음
    case roomNotFound               // 그런 초대 코드가 없음
    case roomFull                   // 정원 초과
    case server(message: String)
    case unknown

    // TODO: 문구는 임의 작성본 — 기획의 에러 문구 가이드 확정 시 일괄 교체 (AuthError와 같은 처지).
    /// 얼럿 메시지 (디자인에 상세 화면이 없으므로 최소 문구).
    public var userMessage: String {
        switch self {
        case .network: "네트워크 연결을 확인해 주세요."
        case .unauthorized: "다시 로그인해 주세요."
        case .invalidRoomName: "방 이름을 입력해 주세요."
        case .invalidInviteCode: "초대 코드를 입력해 주세요."
        case .roomNotFound: "초대 코드를 다시 확인해 주세요."
        case .roomFull: "이 방은 인원이 가득 찼어요."
        case let .server(message): message.isEmpty ? "잠시 후 다시 시도해 주세요." : message
        case .unknown: "알 수 없는 오류가 발생했어요."
        }
    }
}
