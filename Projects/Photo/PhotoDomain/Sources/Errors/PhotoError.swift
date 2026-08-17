/// 필터 조회·사진 업로드가 실패하는 경우를 모아 둔다. Data가 던지고 Feature가 받는다.
///
/// Data는 서버·스토리지에서 난 오류를 반드시 이 타입으로 바꿔 던진다 (`RoomError`와 같은 구조).
public enum PhotoError: Error, Equatable, Sendable {
    case network // 오프라인·타임아웃
    case unauthorized // 401 — 토큰 만료
    case photoExhausted // 방의 남은 장수 소진 — 서버가 업로드를 거절
    case server(message: String)
    case unknown

    // TODO: 문구는 임의 작성본 — 기획의 에러 문구 가이드 확정 시 일괄 교체 (RoomError와 마찬가지다).
    /// 토스트·얼럿에 띄울 문구. 에러가 자기 문구를 들고 다녀야 같은 실패에 화면마다 다른 말이 나오지 않는다.
    public var userMessage: String {
        switch self {
        case .network: "네트워크 연결을 확인해 주세요."
        case .unauthorized: "다시 로그인해 주세요."
        case .photoExhausted: "앗! 장수가 없어서 촬영할 수 없어요."
        case let .server(message): message.isEmpty ? "잠시 후 다시 시도해 주세요." : message
        case .unknown: "알 수 없는 오류가 발생했어요."
        }
    }
}
