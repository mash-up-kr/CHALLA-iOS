import Foundation

/// 사진 기능에서 Feature까지 전달되는 도메인 오류.
///
/// 촬영·업로드·상세·사진첩 저장의 실패를 한 타입으로 모은다. Data·Core 구현이 서버·스토리지·사진첩 API
/// 오류를 반드시 이 타입으로 정규화해 던진다 (`RoomError`와 같은 구조). Domain은 그 원본 오류 타입을 모른다.
public enum PhotoError: Error, Equatable, Sendable {

    /// 오프라인·타임아웃 등 전송 자체가 실패.
    case network

    /// 401 — 토큰 만료. 재로그인이 필요하다.
    case unauthorized

    /// 방의 남은 장수 소진 — 서버가 업로드를 거절.
    case photoExhausted

    /// 서버가 실패를 알림.
    case server(message: String)

    /// 사진첩 추가 권한 없음. 설정으로 안내한다.
    case permissionDenied

    /// 권한은 있으나 사진첩에 쓰지 못함.
    case saveFailed

    /// 그 외 분류 불가능한 오류.
    case unknown

    // TODO: 문구는 임의 작성본 — 기획의 에러 문구 가이드가 확정되면 일괄 교체한다 (RoomError와 마찬가지다).
    /// 토스트·얼럿에 띄울 문구. 에러가 자기 문구를 들고 다녀야 같은 실패에 화면마다 다른 말이 나오지 않는다.
    public var userMessage: String {
        switch self {
        case .network: "네트워크 연결을 확인해 주세요."
        case .unauthorized: "다시 로그인해 주세요."
        case .photoExhausted: "앗! 장수가 없어서 촬영할 수 없어요."
        case let .server(message): message.isEmpty ? "잠시 후 다시 시도해 주세요." : message
        case .permissionDenied: "사진첩 접근 권한이 필요해요. 설정에서 허용해 주세요."
        case .saveFailed: "사진을 저장하지 못했어요."
        case .unknown: "알 수 없는 오류가 발생했어요."
        }
    }
}
