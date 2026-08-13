# 이미지 로딩 규칙

상세: `Projects/Core/CHALLAImageKit/MODULE.md` (캐시 정책 표) · 도해: `docs/imagekit-map.html`

## 원격 이미지는 CHALLAImageKit으로만 로드한다

- SwiftUI `AsyncImage` 사용 금지 — 자체 캐시(메모리·디스크)·다운샘플링·재시도를 전부 우회한다.
- Feature·뷰에서 이미지용 `URLSession` 직접 호출 금지. 외부 이미지 라이브러리(Kingfisher 등) 도입 금지 (#25에서 미채택 결정).
- 뷰에서는 `CHALLAAsyncImage`(CHALLADesignSystem, #43)를 쓴다. 뷰가 아닌 곳에서 바이트가 필요하면 `ImageLoader`를 직접 쓴다.

## 호출 시 지켜야 할 것

- `pointSize`는 실제 표시될 뷰의 pt 크기, `scale`은 화면 배율을 넘긴다 — 로더가 이 값으로
  다운샘플 크기와 캐시 키를 정하므로, 대충 큰 값을 넘기면 캐시가 크기별로 분열되고 메모리가 늘어난다.
- 캐시 상한·정책을 바꾸고 싶으면 하드코딩하지 말고 `ImageCacheConfiguration` 주입으로.
- 로그아웃 등 사용자 데이터 정리 시점에는 상위(App)가 `ImageLoader.removeAll()`을 호출한다.
