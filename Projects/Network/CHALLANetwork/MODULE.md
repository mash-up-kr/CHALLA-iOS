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
| (Alamofire `RequestRetrier`) | `Retrier` / `TokenRefreshRetrier` |
| `NetworkLoggerPlugin` | `LoggingInterceptor` |
| `AccessTokenPlugin` / `AccessTokenAuthorizable` | `AuthInterceptor` / `AccessTokenAuthorizable` + `TokenProvider` |
| `MoyaError` | `NetworkError` |

## 공개 API

### 요청 선언 (Data가 채택)
- `protocol Endpoint` — `baseURL` · `path` · `method` · `task` · `headers`
- `enum HTTPMethod` — `.get` `.post` `.put` `.patch` `.delete`
- `enum HTTPTask` — `.requestPlain` · `.requestData` · `.requestParameters(parameters:encoding:)` · `.requestQueryItems([URLQueryItem])` · `.requestJSONEncodable` · `.uploadMultipart`
  - `.requestQueryItems`는 같은 키가 반복되는 배열 쿼리(`?status=A&status=B`) 전용 — `Parameters`는 딕셔너리라 키 반복을 표현할 수 없다
- `protocol ParameterEncoding` / `struct URLEncoding`(쿼리스트링) · `typealias Parameters = [String: String]`
- `struct MultipartFormData`
- `protocol AccessTokenAuthorizable` · `enum AuthorizationType`(`.none`/`.bearer`)

### 실행
- `protocol HTTPClient` — `decoder: JSONDecoder`(구현체가 한 번 만들어 보관), `request(_:) async throws -> Response`, 편의 `request(_:as:)`(2xx 필터 + `decoder`로 디코딩)
- `final class DefaultHTTPClient` — `URLSession` 기반 구현 (`init(session:interceptors:retrier:)`).
  `retrier`가 재시도를 지시하면 파이프라인 **처음으로** 돌아가므로 `adapt`가 다시 돌아
  갱신된 토큰이 새 요청에 실린다. 요청 조립(`asURLRequest`)은 결과가 같으므로 루프 밖에서 한 번만 한다
- `struct Response` — `statusCode` · `data` · `request` · `headers` + `filter(statusCodes:)` · `filterSuccessfulStatusCodes()` · `map(_:using:)`

### 공통 응답 DTO (Data가 공유)
- `struct BaseResponseDTO<Payload>` — 서버 공통 봉투 `{ success, message, data }`. `unwrap(orServerError:)` · `ensureSuccess(orServerError:)`로 검사하며, 실패 시 던질 도메인 오류는 호출 모듈이 클로저로 넘긴다. 각 Data 모듈은 자기 오류를 묶은 무인자 `unwrap()` / `ensureSuccess()` 확장을 둔다.
- `struct EmptyResponseDTO` — 페이로드가 없는(무시하는) 응답용 (`BaseResponseDTO<EmptyResponseDTO>` + `ensureSuccess()`).

### 인터셉터 · 인증 · 오류
- `protocol Interceptor` — `adapt` · `willSend` · `didReceive` (모두 기본 구현 있음)
- `struct AuthInterceptor` · `struct LoggingInterceptor`
  - `LoggingInterceptor(level:)` — `.none` / `.basic`(메서드·URL·상태 코드) / `.verbose`(헤더·본문까지).
    `.verbose`의 응답 본문은 `os.Logger`의 한 줄 1024바이트 상한에 걸려 잘리지 않도록
    `body[n/N]` 순번을 붙여 여러 줄로 나눠 남긴다 (본문 전문 확인용). 값은 `.private`이라
    Xcode 디버거가 붙은 콘솔에서만 보인다
- `protocol TokenProvider` — 구현은 `AuthData`

- `enum NetworkError` — 취소는 여기에 포함되지 않는다. 전송이 취소되면 `NetworkError`로 감싸지 않고
  `CancellationError`를 그대로 던지며, `Interceptor.didReceive`에도 실패로 통보하지 않는다
  (취소를 서버 장애로 오인해 재시도·로깅이 잘못 도는 것을 막는다)

### 재시도 · 토큰 갱신
- `protocol Retrier` — `shouldRetry(_:endpoint:attempt:)`. 응답을 보고 같은 요청을 다시 보낼지 결정한다
- `protocol TokenRefreshing` — `refreshToken(replacing staleAccessToken:)`. 구현은 `AuthData`.
  `staleAccessToken`은 401을 받은 요청이 실어 보낸 토큰이다 — 그 사이 다른 요청이 이미 갱신했는지 판단하는 데 쓴다
- `struct TokenRefreshRetrier: Retrier` — 401 + `authorizationType == .bearer`일 때만 갱신을 부르고,
  성공하면 **1회만** 재시도한다(갱신한 토큰으로도 401이면 갱신으로 풀 문제가 아니다).
  갱신 실패 시 재시도하지 않고 401을 그대로 올려보내 Data가 각 도메인 오류로 정규화하게 둔다.
  토큰을 싣지 않는 엔드포인트(로그인·갱신)의 401은 자격 증명 자체가 거절된 것이라 건너뛴다

### 서버 환경
- `enum CHALLAAPIEnvironment` — `static let baseURL: URL`. 도메인마다 서버가 갈리지 않는 한
  모든 Data 모듈(`AuthData`·`RoomData` 등)의 `Endpoint.baseURL`이 공유하는 단일 소스.
  앱 타깃 Info.plist(`API_SCHEME`/`API_HOST`/`API_PORT`)에서 읽으며, scheme·host가 비었거나
  형식이 어긋나면 어느 키가 문제인지 밝힌 `fatalError`로 즉시 중단한다. 이 값은
  `Configs/Shared.xcconfig`(gitignore) → `Project.makeAppProject(usesAPIEnvironment: true)`로 주입된다.
  서버 주소는 공개하지 않는 값이라 git에 올리지 않으며, 신규 클론 시 `Shared.xcconfig.template`를
  복사해 채운다. 서버 이전·HTTPS 전환 시 `Configs/Shared.xcconfig` 한 곳만 고치면
  baseURL과 ATS 예외가 함께 바뀐다.

## 사용 예시 (Data 레이어)

```swift
import CHALLANetwork

enum RoomEndpoint: Endpoint {
    case rooms
    case create(RoomCreateRequest)

    var baseURL: URL { CHALLAAPIEnvironment.baseURL }   // 모든 Data가 공유하는 단일 소스
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
    let client: HTTPClient                        // 조립 지점이 DefaultHTTPClient 주입

    func fetchRooms() async throws -> [Room] {
        let dtos = try await client.request(RoomEndpoint.rooms, as: [RoomDTO].self)
        return dtos.map { $0.toDomain() }
    }
}
```

조립 지점(앱 타깃의 `CompositionRoot`) 예:

```swift
let client = DefaultHTTPClient(
    interceptors: [
        AuthInterceptor(tokenProvider: keychainTokenProvider),  // 구현은 AuthData
        LoggingInterceptor(level: .verbose)  // DEBUG에서만 — 릴리스는 .basic
    ],
    retrier: TokenRefreshRetrier(refresher: authTokenRefresher)  // 구현은 AuthData
)
```

> 갱신 요청 자체는 **retrier를 달지 않은 별도 클라이언트**로 보내야 한다.
> 같은 클라이언트를 쓰면 갱신의 401이 다시 갱신을 부르는 재귀가 된다 (`CHALLAApp/CompositionRoot` 참고).

## 의존성

- **이 모듈이 의존**: 없음 (`Foundation` · `os`만 사용, 외부 패키지 0)
- **이 모듈에 의존**: `*Data` 모듈들 (RoomData · PhotoData · AuthData · UserData · SettingData 등) · 테스트 지원 모듈 `CHALLANetworkTesting`
- **연결**: `TokenProvider` 구현(`AuthData`)과 `HTTPClient` 주입은 조립 지점(앱 타깃의 `CompositionRoot`)이 담당

## 테스트 실행 방법

```bash
mise exec -- tuist test CHALLANetwork
```

Swift Testing 기반 테스트 (7 suite) — Swift 6 언어 모드에서 통과:
- `BaseResponseDTOTests` — 공용 봉투의 `unwrap`/`ensureSuccess`(성공·`success=false`·`data` 누락, 클로저 오류에 서버 메시지 전달)
- `URLEncodingTests` — 쿼리 인코딩·이스케이프·빈 파라미터
- `EndpointRequestTests` — Endpoint → URLRequest 변환 (plain·data·JSON·params·multipart)
- `ResponseTests` — 상태 코드 필터·디코딩·오류 매핑
- `AuthInterceptorTests` — 토큰 주입·`.none`/토큰 없음
- `TokenRefreshRetrierTests` — 401 판정, 갱신 성공/실패, 상태 코드·`authorizationType` 필터,
  재시도 횟수 상한, 만료 토큰 전달(Bearer 접두사 제거)
- `HTTPClientTests` — `URLProtocol` 스텁으로 전체 파이프라인 (성공·404·전송실패·취소·인터셉터 반영·응답 헤더 노출,
  401 재시도 시 갱신된 토큰이 실리는지 · 갱신 실패 시 재시도 없음 · 재시도 1회 상한 · retrier 없을 때 기존 동작)
- `CHALLAAPIEnvironmentTests` — Info.plist 값으로 baseURL 조립 (port 생략·비숫자 무시·scheme 형식 검사)
