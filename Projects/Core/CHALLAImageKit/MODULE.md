# CHALLAImageKit

## 책임 (레이어: Core)

자체 구현 이미지 로딩 스택. 원본 이미지 바이트를 뷰에 필요한 픽셀 크기로만 디코딩해
(다운샘플링) 그리드·셀 표시 시 메모리 사용량을 줄이고, 메모리·디스크 2단 캐시로
재디코딩·재다운로드를 피한다.

시스템 프레임워크(Foundation · CoreGraphics · ImageIO · UIKit · CryptoKit · UniformTypeIdentifiers)만 사용하며,
CHALLA 모듈·외부 패키지를 하나도 import하지 않는다. `CHALLANetwork`와도 무관하다
(아키텍처 규칙 6 저촉 없음 — "OS를 만지면 Core").

> 현재 다운샘플러 + 2단 캐시(메모리·디스크) + 로더(`ImageLoader`)까지 구현됨.
> DS 뷰(`CHALLAAsyncImage`)는 후속 단계 (설계: 이슈 #25).

전체 도해(파이프라인 · 타입 변환 · 캐시 삭제 정책 · 테스트 43개 카탈로그): [`docs/imagekit-map.html`](../../../docs/imagekit-map.html) — 브라우저로 열면 경로별 인터랙티브 구조도가 나온다.

## 캐시 정책

이 모듈의 캐시가 따르는 규칙 전체. 여기 없는 캐시 동작은 없다.

| 항목 | 정책 |
| :-- | :-- |
| 구조 | 메모리 · 디스크 2단. 메모리는 디코딩된 `UIImage`(표시 즉시 사용), 디스크는 다운샘플된 HEIC 바이트(재실행 생존) |
| 키 | `URL + 타깃 픽셀 크기(ceil(pt × scale))`. 같은 URL이라도 표시 크기가 다르면 별도 항목 |
| 상한 | 메모리 100MB(cost 합산) · 디스크 500MB — `.default` 기준, 생성자 주입으로 변경 가능 |
| 메모리 삭제 | NSCache 자동 방출(cost 상한 초과 · 시스템 메모리 압박 시). **방출 순서 비보장**. 별도 알림 구독 없음 |
| 디스크 삭제 | 자체 LRU — 저장할 때마다 총 용량 검사, 상한 초과분을 파일 수정일이 오래된 순으로 삭제. 조회 적중 시 수정일 갱신 |
| 저장 위치 | `Caches/CHALLAImageCache` — OS가 저장 공간 부족 시 지울 수 있는 위치를 일부러 선택 (재다운로드로 복구 가능한 데이터만 보관) |
| OS 삭제 | 관리 수단으로 쓰지 않음(시점 보장 없음). 파일이 사라져도 미스 처리 → 네트워크 폴백으로 견딤 |
| 전체 정리 | 상위 계층이 `ImageLoader.removeAll()` 호출(로그아웃 등) — 진행 중 작업 취소 + 두 캐시 모두 비움 |
| HTTP 캐시 | `URLCache` 미사용 — 켜면 원본이 세션 캐시에, 가공본이 디스크 캐시에 이중 저장됨 |

## 공개 API

| API | 설명 |
| :-- | :-- |
| `ImageDownsampler` | `Sendable` 값 타입. ImageIO 썸네일 디코딩으로 타깃 픽셀 크기만큼만 디코딩 |
| `ImageDownsamplingError` | `invalidData` / `thumbnailCreationFailed` / `invalidTargetSize` |
| `PixelSize` | pt·scale을 정수 픽셀로 환산·보관. 캐시 키의 크기 성분 |
| `ImageCacheKey` | `URL + PixelSize` 조합 키. 디스크 파일명용 `storageIdentifier`(SHA256) |
| `ImageCacheConfiguration` | 메모리/디스크 용량·경로 설정. `.default`(메모리 100MB / 디스크 500MB) |
| `MemoryImageCache` | NSCache 래핑. 다운샘플 `UIImage`를 메모리 보관, cost 기반 자동 방출 |
| `DiskImageCache` | `actor`. 다운샘플 바이트를 디스크 저장, 용량 초과 시 LRU 삭제 |
| `ImageLoader` | `actor`. 메모리→디스크→네트워크 조회 오케스트레이터. 같은 키 중복 제거(coalescing), 캐시 승격 |
| `ImageDataFetching` | 네트워크 페치 추상화(주입 지점). 기본 구현 `URLSessionImageDataFetcher`(URLCache 끈 세션) |
| `ImageLoadingError` | `invalidResponse` / `httpStatus` / `emptyData` / `downsampling` / `encodingFailed` / `networkFailed` / `cancelled` |

### 다운샘플링

```swift
public struct ImageDownsampler: Sendable {
    public init()
    /// maxPixelSize = ceil(max(pointSize.width, pointSize.height) * scale).
    /// EXIF 회전 반영, 생성 시 즉시 디코딩. 원본이 타깃보다 작으면 업스케일하지 않는다.
    public func downsample(data: Data, pointSize: CGSize, scale: CGFloat) throws -> CGImage
}

public enum ImageDownsamplingError: Error, Sendable, Equatable {
    case invalidData            // 디코딩 가능한 이미지 데이터가 아님
    case thumbnailCreationFailed
    case invalidTargetSize      // pointSize·scale이 0 이하
}
```

동기 CPU 작업이므로 호출부(로더)가 백그라운드(`@concurrent`)에서 실행할 책임을 진다.

### 캐시 키

```swift
public struct PixelSize: Hashable, Sendable {
    public init(width: Int, height: Int)             // 음수는 0으로 보정
    public init(pointSize: CGSize, scale: CGFloat)   // ceil(pt * scale)
    public let width: Int
    public let height: Int
}

public struct ImageCacheKey: Hashable, Sendable {
    public init(url: URL, pixelSize: PixelSize)
    public let url: URL
    public let pixelSize: PixelSize
    public var storageIdentifier: String   // SHA256 16진수 64자 (디스크 파일명)
}
```

키에는 pt·scale이 아니라 **최종 픽셀 크기**가 들어간다. `100pt@3x`와 `150pt@2x`는 둘 다
300px라 같은 항목으로 합쳐져 중복 저장을 막는다. 같은 URL이라도 크기가 다르면
(그리드 300px vs 상세 1200px) 다른 키다.

### 캐시

```swift
public struct ImageCacheConfiguration: Sendable {
    public init(memoryCostLimitBytes: Int, diskDirectory: URL, diskCapacityBytes: Int)
    public static var `default`: ImageCacheConfiguration   // 메모리 100MB / 디스크 500MB
}

public final class MemoryImageCache: @unchecked Sendable {
    public init(costLimit: Int)
    public func image(for key: ImageCacheKey) -> UIImage?
    public func insert(_ image: UIImage, for key: ImageCacheKey, cost: Int)
    public func removeAll()
}

public actor DiskImageCache {
    public init(directory: URL, capacityBytes: Int) throws
    public func data(for key: ImageCacheKey) -> Data?     // 적중 시 수정일 갱신(LRU)
    public func store(_ data: Data, for key: ImageCacheKey)
    public func removeAll()
    public func totalBytes() -> Int
}
```

- 메모리 캐시는 디코딩된 `UIImage`(즉시 표시용), 디스크 캐시는 다운샘플 바이트(`Data`)를 저장한다.
- 메모리 방출은 NSCache에, 디스크 방출은 파일 수정일 기반 LRU에 위임한다.
- `URLCache`(HTTP 캐시)는 사용하지 않는다 — 원본만 캐싱돼 다운샘플·크기별 캐싱과 맞지 않고
  이중 저장을 유발한다.

### 로더

```swift
public protocol ImageDataFetching: Sendable {
    func fetch(_ url: URL) async throws -> (Data, URLResponse)   // 실패 시 URLError
}
public struct URLSessionImageDataFetcher: ImageDataFetching {
    public init(session: URLSession = ...)   // 기본값: URLCache를 끈 전용 세션
}

public enum ImageLoadingError: Error, Sendable, Equatable {
    case invalidResponse          // HTTPURLResponse 아님
    case httpStatus(Int)          // 2xx 벗어남
    case emptyData                // 0바이트 응답
    case downsampling(ImageDownsamplingError)
    case encodingFailed           // 디스크 저장용 HEIC 재인코딩 실패
    case networkFailed(URLError.Code)  // 서버 응답 전 전송 실패(오프라인·타임아웃)
    case cancelled
}

public actor ImageLoader {
    public init(configuration: ImageCacheConfiguration = .default,
                fetcher: ImageDataFetching = URLSessionImageDataFetcher(),
                retryDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]) throws
    public func image(from url: URL, pointSize: CGSize, scale: CGFloat) async throws -> UIImage
    public func removeAll() async   // 진행 중 작업 취소 + 메모리·디스크 비우기
}
```

- 조회 순서: **메모리 히트 → 중복 제거(진행 중 동일 요청 공유) → 디스크 히트(디코딩·메모리 승격,
  실패 시 조용히 네트워크 폴백) → 네트워크(다운샘플·HEIC 인코딩 후 디스크·메모리 저장)**.
- 무거운 CPU 작업(다운샘플·인코딩·디코딩)은 `Task.detached(.utility)`로 액터 밖에서 실행한다
  (iOS 17이라 `@concurrent` 대신 detached). 비-Sendable `CGImage`는 detached 클로저 안에 가둔다.
- 같은 URL이라도 표시 크기(픽셀)가 다르면 별도 항목이다. `scale`은 호출부(뷰)가 넘긴다 —
  Core는 `UIScreen`을 만지지 않는다. 반환 `UIImage`에는 `scale`을 실어 표시 크기를 논리 pt로 맞춘다.
- 네트워크는 **일시적 전송 실패**(타임아웃·연결 끊김·DNS 등)만 `retryDelays` 간격으로 지수 백오프 재시도한다.
  `.cancelled`·재시도 불가 코드(`.badURL` 등)·HTTP 상태 오류(404 등)는 재시도하지 않는다.
- **메모리 경고 대응**은 별도 알림 구독 없이 `NSCache`(메모리 캐시)의 시스템 압박 시 자동 방출로 충족한다
  (Core가 `UIApplication` 알림을 구독하면 레이어 위반). 강제 정리가 필요하면 상위가 `removeAll()`을 호출한다.

## 의존 관계

- 이 모듈이 의존하는 모듈: 없음 (외부 패키지 0개, CHALLA 모듈 0개 — 시스템 프레임워크만)
- 이 모듈에 의존하는 모듈: `CHALLADesignSystem` — `CHALLAAsyncImage`가 로더를 사용 (이슈 #43)

## 테스트 실행 방법

이미지 픽스처는 번들 리소스 없이 `Tests/Support/TestImageFactory.swift`가 런타임 생성한다.
디스크 캐시 테스트는 테스트마다 고유한 임시 디렉터리를 만들어 서로 격리한다.
로더 테스트는 `Tests/Support/MockImageDataFetcher.swift`(호출 횟수 계수)를 주입해 네트워크 없이
캐시 히트·중복 제거·에러 매핑을 검증한다 — 시뮬레이터 위에서 돌지만 실제 서버에 붙지 않는다.

```bash
mise exec -- tuist generate --no-open
xcodebuild -workspace CHALLA.xcworkspace -scheme CHALLAImageKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
