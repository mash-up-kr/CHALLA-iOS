# RoomCoverUI

## 레이어와 책임

Feature가 함께 쓰는 **화면 지원 모듈**(ShootEntry와 같은 위치). 서버가 준 커버 값(RoomDomain)을 화면에 올린다 —
색 hex를 `Color`로 바꾸고, 스티커 SVG를 받아 그리고, 방금 고른 사진 바이트를 `Image`로 만든다.
홈 카드와 방 상세의 커버 수정 화면이 같은 방식으로 그려야 하는데 Feature끼리는 import 할 수 없어(규칙 3) 따로 뗐다.

## 공개 API

- `RoomCoverColor.color: Color` — 서버 `hex`를 그대로 칠한다. 팔레트는 서버가 정하므로 디자인 토큰에 매핑하지 않는다.
  형식이 어긋나면 `CHALLAColor.Label.neutral`
- `RoomCoverStickerView(url:color:)` — 스티커 도안을 받아 주어진 색으로 칠한다. 받아오기 전·실패는 아무것도 그리지 않는다
  - **앱은 스티커 그림을 갖지 않는다.** 서버가 SVG로만 주는데 iOS는 SVG를 런타임에 디코딩하지 못해,
    `CHALLAImageKit`의 `VectorDrawingLoader`가 도형으로 파싱한 것을 SwiftUI `Path`로 채운다
  - 파일에 박힌 색은 쓰지 않는다 — 같은 도안을 사용자가 고른 색으로 칠해야 하기 때문(도안 7 × 색 7)
- `EnvironmentValues.roomCoverStickerLoader` — 위 뷰가 쓰는 로더. 기본값은 앱당 하나를 공유한다
  (로더마다 캐시가 따로라 화면마다 만들면 같은 SVG를 다시 받는다). 테스트·프리뷰가 네트워크를 끊을 때 주입한다
- `RoomCoverPhoto(data:content:)` — 방금 고른 사진 바이트를 `Image?`로 한 번만 디코딩해 `content`에 넘긴다.
  색·스티커가 바뀌어 다시 그릴 때 JPEG를 다시 풀지 않는다

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `CHALLADesignSystem` · `CHALLAImageKit`
- **이 모듈에 의존**: `HomeFeature` · `RoomDetailFeature`

## 테스트 실행 방법

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme RoomCoverUITests -destination 'platform=iOS Simulator,name=<기기>' test
```

`RoomCoverColorTests` — hex 파싱(# 유무·대소문자·잘못된 값). 스티커 도형 파싱·캐시는 `CHALLAImageKit` 테스트가 본다.
