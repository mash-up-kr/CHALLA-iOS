# CHALLADesignSystem

## 책임 (레이어: UI)

찰나의 디자인 토큰(색·타이포그래피·둥글기·아이콘)과 공용 SwiftUI 컴포넌트를 제공한다.

이 모듈은 SwiftUI와 `CHALLAImageKit`(Core — `CHALLAAsyncImage`의 이미지 로딩용)만
import한다. Feature가 이 모듈을 가져다 쓰는 것이며, 역방향(디자인 시스템 → Feature)
참조는 금지다 (아키텍처 규칙 5). 네트워크·디스크를 만지는 로딩 로직은 전부 Core에 있고,
이 모듈의 뷰는 로더를 주입받아 소비만 한다 (순수성 유지).

## 공개 API

### Foundation (토큰)

| API | 설명 |
| :-- | :-- |
| `CHALLAColor` | 색 토큰. Figma Theme 변수와 1:1 (Primary/Label/Background/Status/Line/Static/Material) |
| `CHALLATypography` + `challaFont(_:)` | 타이포 토큰. Figma 줄 높이까지 재현 (`.heading` / `.body` / `.caption`) |
| `CHALLARadius` | 모서리 둥글기 토큰 (small 8 / medium 10 / large 12) |
| `CHALLAIcon` | 아이콘 토큰 20종 + `Size`(16~32pt) + `image(size:color:)` |
| `CHALLAFontRegister` | 커스텀 폰트 등록. 앱 진입점(@main) init에서 1회 호출 |

### Components

| API | 설명 |
| :-- | :-- |
| `CHALLATextButton` | 텍스트 버튼. variant(primary/neutral/transparent) × size(large/medium/small), leading/trailing 아이콘 옵션 |
| `CHALLAIconButton` | 아이콘 버튼. 정사각(54/40/32), variant·size는 텍스트 버튼과 공용 |
| `CHALLAButtonVariant` / `CHALLAButtonSize` | 두 버튼이 공유하는 스타일·크기 enum |
| `CHALLAAsyncImage` | 원격 이미지 뷰. 자기 크기·배율을 측정해 `ImageLoader`로 로드(다운샘플+2단 캐시), 성공 시 페이드인 |
| `CHALLAAsyncImagePhase` | 로딩 상태 enum (`empty`/`success(Image)`/`failure(Error)`) + `image`/`error` 편의 접근 |
| `EnvironmentValues.challaImageLoader` | 로더 주입 통로. 기본값은 `.default` 설정의 공유 로더 — 주입 없이 동작 |

버튼 비활성화는 별도 파라미터 없이 SwiftUI 표준 `.disabled(_:)`로 제어한다
(내부에서 `@Environment(\.isEnabled)`를 읽어 비활성 색을 적용).

### CHALLAAsyncImage 사용법

```swift
// 기본형 — 로딩 중·실패 시 DS 배경 박스, 성공 시 페이드인
CHALLAAsyncImage(url: photo.url)
    .scaledToFill()
    .frame(width: 160, height: 160)

// 커스텀형 — content·placeholder 지정 (SwiftUI AsyncImage와 같은 모양)
CHALLAAsyncImage(url: photo.url) { image in
    image.resizable().scaledToFill()
} placeholder: {
    CHALLAColor.Background.level2
}

// 커스텀 로더가 필요하면(로그아웃 removeAll 연결 등) 앱 루트에서 교체
RootView().environment(\.challaImageLoader, myLoader)
```

- 크기(`pointSize`)와 배율(`displayScale`)은 뷰가 스스로 측정해 로더에 넘긴다.
- url·크기 변경 시 이전 로드를 취소하고 재로드하며, 뷰가 사라지면 자동 취소된다.
- 실패 시 별도 UI 없이 placeholder를 유지한다 (#25 결정). 재등장 시 자연 재시도.

## 의존 관계

- 이 모듈이 의존하는 모듈: `CHALLAImageKit` (Core — 규칙 4에 따라 허용)
- 이 모듈에 의존하는 모듈: 모든 Feature, `CHALLADesignSystemApp`

## 사용 규칙

- 다른 모듈에서 `Color(hex:)`·`Font.custom` 등 원시 호출 금지 — 반드시 토큰만 사용
  (상세: `.claude/rules/design-system.md`)
- 새 토큰·컴포넌트를 추가하면 `CHALLADesignSystemApp` 갤러리에 Variant 전수를 나열한다
  — 누락 시 디자이너 검수 불가
- 아이콘 추가 절차: Figma 인벤토리 등록 → SVG export → `Resources/Icons.xcassets`에
  imageset 추가(template 렌더링 + 벡터 보존 필수) → `CHALLAIcon`에 케이스 추가
  (갤러리는 `allCases` 기반이라 자동 반영)

## 검증 방법

- **시각 검증(1차)**: `CHALLADesignSystemApp` 스킴 실행 → 갤러리에서 Figma와 대조.
  뷰(버튼·아이콘 렌더링)는 유닛테스트 대신 이 갤러리 검수가 테스트를 대신한다
- **로직 테스트**: 버튼 색 매핑(`CHALLAButtonVariant`) 등 순수 로직의 Swift Testing 검증은
  테스트 타깃 자동화(이슈 #8) 머지 후 추가 예정
