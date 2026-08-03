# CHALLAImageKit

## 책임 (레이어: Core)

자체 구현 이미지 로딩 스택. 원본 이미지 바이트를 뷰에 필요한 픽셀 크기로만 디코딩해
(다운샘플링) 그리드·셀 표시 시 메모리 사용량을 줄인다.

시스템 프레임워크(Foundation · CoreGraphics · ImageIO · UIKit)만 사용하며,
CHALLA 모듈·외부 패키지를 하나도 import하지 않는다. `CHALLANetwork`와도 무관하다
(아키텍처 규칙 6 저촉 없음 — "OS를 만지면 Core").

> 현재는 1단계(다운샘플러)만 구현됨. 캐시(`MemoryImageCache`/`DiskImageCache`),
> 로더(`ImageLoader`), DS 뷰(`CHALLAAsyncImage`)는 후속 단계 (설계: 이슈 #25).

## 공개 API

| API | 설명 |
| :-- | :-- |
| `ImageDownsampler` | `Sendable` 값 타입. ImageIO 썸네일 디코딩으로 타깃 픽셀 크기만큼만 디코딩 |
| `ImageDownsamplingError` | `invalidData` / `thumbnailCreationFailed` / `invalidTargetSize` |

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

## 의존 관계

- 이 모듈이 의존하는 모듈: 없음 (외부 패키지 0개, CHALLA 모듈 0개 — 시스템 프레임워크만)
- 이 모듈에 의존하는 모듈: (예정) `CHALLADesignSystem` — `CHALLAAsyncImage`가 로더를 사용

## 테스트 실행 방법

픽스처는 번들 리소스 없이 `Tests/Support/TestImageFactory.swift`가 런타임 생성한다.

```bash
mise exec -- tuist generate --no-open
xcodebuild -workspace CHALLA.xcworkspace -scheme CHALLAImageKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
