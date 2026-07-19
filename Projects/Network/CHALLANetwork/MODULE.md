# CHALLANetwork

## 레이어와 책임

**Network 레이어** (서버 접점 · **Data 전용**). 서버와의 HTTP 통신을 담당하는 순수 네트워킹 모듈이다.
Moya 라이브러리의 설계 형태를 본떠 `URLSession` 위에 얹은 얇은 추상화 레이어로, 외부 네트워킹 의존성이 없다.

Data 레이어(Repository 구현)가 API 요청을 **선언적으로** 기술(`Endpoint`)하면, 이 모듈이 그것을
`URLRequest`로 변환·전송하고 `Response`로 돌려준다. 서버 주소·경로·인증 방식은 Data가 정하고,
이 모듈은 "받아서 보내고 되돌려주는" 역할만 한다.

아키텍처 규칙 6에 따라 **`CHALLANetwork`는 Data만 import 한다** — Feature·Domain은 서버의 존재를 모른다.
토큰 저장소(Keychain 등)의 존재도 모른다: 인증 토큰은 `TokenProvider` 프로토콜로 추상화하고, 구현은 `AuthData`가 맡는다.

**동시성**: 공개 타입(`Endpoint`·`HTTPTask`·`HTTPClient`·`Interceptor`·`Response`·`TokenProvider` 등)은 모두 `Sendable`이다
(`@unchecked` 미사용). Swift 6 strict concurrency(`complete`)에서 경고 없이 컴파일되며, TCA `@Dependency`로
Repository에 주입해도 안전하다. `Response`는 비-Sendable `HTTPURLResponse` 대신 `headers: [String: String]`를 노출한다.

## Moya 대응 관계

| Moya | CHALLANetwork |
| :-- | :-- |
| `TargetType` | `Endpoint` |
| `Method` | `HTTPMethod` |
| `Task` | `HTTPTask` |
| `ParameterEncoding` (URL query) | `ParameterEncoding` / `URLEncoding` |
| `MultipartFormData` | `MultipartFormData` |
| `MoyaProviderType` / `MoyaProvider` | `HTTPClient` / `DefaultHTTPClient` |
| `Response` | `Response` |
| `PluginType` | `Interceptor` |
| `NetworkLoggerPlugin` | `LoggingInterceptor` |
| `AccessTokenPlugin` / `AccessTokenAuthorizable` | `AuthInterceptor` / `AccessTokenAuthorizable` + `TokenProvider` |
| `MoyaError` | `NetworkError` |

## 공개 API

### 요청 선언 (Data가 채택)
- `protocol Endpoint` — `baseURL` · `path` · `method` · `task` · `headers`
- `enum HTTPMethod` — `.get` `.post` `.put` `.patch` `.delete`
- `enum HTTPTask` — `.requestPlain` · `.requestData` · `.requestParameters(parameters:encoding:)` · `.requestJSONEncodable` · `.uploadMultipart`
- `protocol ParameterEncoding` / `struct URLEncoding`(쿼리스트링) · `typealias Parameters = [String: String]`
- `struct MultipartFormData`
- `protocol AccessTokenAuthorizable` · `enum AuthorizationType`(`.none`/`.bearer`)

### 실행
- `protocol HTTPClient` — `request(_:) async throws -> Response`, 편의 `request(_:as:using:)`(2xx 필터 + 디코딩)
- `final class DefaultHTTPClient` — `URLSession` 기반 구현 (`init(session:interceptors:)`)
- `struct Response` — `statusCode` · `data` · `request` · `headers` + `filter(statusCodes:)` · `filterSuccessfulStatusCodes()` · `map(_:using:)`

### 인터셉터 · 인증 · 오류
- `protocol Interceptor` — `adapt` · `willSend` · `didReceive` (모두 기본 구현 있음)
- `struct AuthInterceptor` · `struct LoggingInterceptor`
- `protocol TokenProvider` — 구현은 `AuthData`
- `enum NetworkError`

## 사용 예시 (Data 레이어)

```swift
import CHALLANetwork

enum RoomEndpoint: Endpoint {
    case rooms
    case create(RoomCreateRequest)

    var baseURL: URL { URL(string: "https://api.challa.app")! }
    var path: String {
        switch self {
        case .rooms, .create: return "/rooms"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .rooms:  return .get
        case .create: return .post
        }
    }
    var task: HTTPTask {
        switch self {
        case .rooms:               return .requestPlain
        case .create(let request): return .requestJSONEncodable(request)
        }
    }
}

struct DefaultRoomRepository: RoomRepository {   // 인터페이스는 RoomDomain
    let client: HTTPClient                        // DIContainer가 DefaultHTTPClient 주입

    func fetchRooms() async throws -> [Room] {
        let dtos = try await client.request(RoomEndpoint.rooms, as: [RoomDTO].self)
        return dtos.map { $0.toDomain() }
    }
}
```

DIContainer 조립 예:

```swift
let client = DefaultHTTPClient(
    interceptors: [
        AuthInterceptor(tokenProvider: keychainTokenProvider),  // 구현은 AuthData
        LoggingInterceptor(level: .basic)
    ]
)
```

## 의존성

- **이 모듈이 의존**: 없음 (`Foundation` · `os`만 사용, 외부 패키지 0)
- **이 모듈에 의존**: `*Data` 모듈들 (RoomData · PhotoData · AuthData · UserData · SettingData 등) · 검수앱 `CHALLANetworkApp`
- **연결**: `TokenProvider` 구현(`AuthData`)과 `HTTPClient` 주입은 DIContainer가 담당

## 검수앱 (CHALLANetworkApp)

`Projects/Network/CHALLANetworkApp` — 이 모듈을 단독 실행·검증하는 데모앱
(디자인시스템 검수앱 `CHALLADesignSystemApp`과 같은 "대상 모듈 옆" 배치).
JSONPlaceholder를 대상으로 `Endpoint` 선언 → `DefaultHTTPClient` 실행 → 응답/오류 표시까지의
전체 흐름을 버튼으로 확인할 수 있다 (requestPlain · URLEncoding · requestJSONEncodable · 404 · 인증 인터셉터).

```bash
mise exec -- tuist generate
# Xcode에서 CHALLANetworkApp 스킴 실행
```

## 테스트 실행 방법

```bash
mise exec -- tuist test CHALLANetwork
```

Swift Testing 기반 테스트 23개 (5 suite) — Swift 6 언어 모드에서 통과:
- `URLEncodingTests` — 쿼리 인코딩·이스케이프·빈 파라미터
- `EndpointRequestTests` — Endpoint → URLRequest 변환 (plain·data·JSON·params·multipart)
- `ResponseTests` — 상태 코드 필터·디코딩·오류 매핑
- `AuthInterceptorTests` — 토큰 주입·`.none`/토큰 없음
- `HTTPClientTests` — `URLProtocol` 스텁으로 전체 파이프라인 (성공·404·전송실패·인터셉터 반영·응답 헤더 노출)
