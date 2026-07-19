import Foundation

/// 하나의 API 요청을 선언적으로 기술하는 타입. Moya의 `TargetType`에 대응한다.
///
/// Data 레이어(예: `RoomData`)가 aggregate 단위로 이 프로토콜을 채택한 enum을 만들어
/// 각 case를 API 하나에 매핑한다. `CHALLANetwork`는 서버 주소나 경로를 모르고,
/// 이 선언을 받아 `URLRequest`로 변환·전송하는 역할만 한다.
///
/// ```swift
/// enum RoomEndpoint: Endpoint {
///     case rooms
///     case create(RoomCreateRequest)
///
///     var baseURL: URL { URL(string: "https://api.challa.app")! }
///     var path: String {
///         switch self {
///         case .rooms:  return "/rooms"
///         case .create: return "/rooms"
///         }
///     }
///     var method: HTTPMethod {
///         switch self {
///         case .rooms:  return .get
///         case .create: return .post
///         }
///     }
///     var task: HTTPTask {
///         switch self {
///         case .rooms:               return .requestPlain
///         case .create(let request): return .requestJSONEncodable(request)
///         }
///     }
/// }
/// ```
public protocol Endpoint: Sendable {

    /// 서버 기본 URL (스킴 + 호스트, 필요 시 공통 prefix 포함).
    var baseURL: URL { get }

    /// `baseURL`에 이어붙일 경로. 예: `"/rooms"`.
    var path: String { get }

    /// HTTP 메서드.
    var method: HTTPMethod { get }

    /// 요청 본문/쿼리 구성 방식. Moya의 `Task`에 대응한다.
    var task: HTTPTask { get }

    /// 이 요청에만 붙는 추가 헤더. 공통 헤더(인증 등)는 `Interceptor`가 담당한다.
    var headers: [String: String]? { get }
}

public extension Endpoint {
    /// 헤더는 선택 사항 — 미구현 시 nil.
    var headers: [String: String]? { nil }
}

// MARK: - AccessTokenAuthorizable

/// 인증 토큰 부착 방식. Moya의 `AuthorizationType`에 대응한다.
public enum AuthorizationType: Sendable {
    /// 인증 헤더를 붙이지 않음 (로그인/회원가입 등 공개 API).
    case none
    /// `Authorization: Bearer <token>` 형태.
    case bearer
}

/// 엔드포인트가 인증 토큰 부착 여부를 스스로 선언할 수 있게 하는 프로토콜.
/// Moya의 `AccessTokenAuthorizable`에 대응하며, `AuthInterceptor`가 이 선언을 참조한다.
/// 채택하지 않은 엔드포인트는 `AuthInterceptor` 기본 정책(`.bearer`)을 따른다.
public protocol AccessTokenAuthorizable {
    var authorizationType: AuthorizationType { get }
}
