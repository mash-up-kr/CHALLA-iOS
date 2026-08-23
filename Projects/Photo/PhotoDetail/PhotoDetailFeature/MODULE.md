# PhotoDetailFeature

## 레이어와 책임

**Feature 레이어**. 사진 상세 화면의 TCA Feature 모듈이다 — 방의 인화된 사진을 좌우로 넘겨 보고,
이모지 리액션을 남기고, 사진첩에 저장한다. 서버·사진첩의 존재는 모르고 `PhotoDomain`의 UseCase 세 개만
`@Dependency`로 받는다 (아키텍처 규칙 2). 라이브 구현은 실행 앱의 `CompositionRoot`가 주입한다.

화면 닫기는 이 모듈이 하지 않는다 — `delegate` 액션으로 parent(App)에 위임한다 (규칙 3).

채팅은 이 화면의 몫이 아니다. 시안 하단의 입력창은 모양만 그려 두고 동작은 후속 이슈에서 붙인다.

## 공개 API

### `PhotoDetailFeature` (@Reducer)

- `State` — `roomID` · `roomTitle` · `currentUserID`(리액션 주체) · `photos: IdentifiedArrayOf<Photo>` ·
  `selectedPhotoID` · `isLoading` · `isSaving` · `reactionBurst: ReactionBurst?`(애니메이션 트리거) ·
  `stickerSlots` · `reactionsLoaded`/`reactionsLoading`(펼친 사진 리액션 지연 조회 캐시) · `alert`(@Presents) · 계산값 `selectedPhoto`
  - `init(roomID:roomTitle:currentUserID:initialPhotoID:)` — `initialPhotoID`를 주면 그 장을 펼친 채로 시작한다
    (목록에 없으면 첫 장으로 떨어진다)
- `ReactionBurst` — `id: UUID` + `kind`. 이모지 쏟아지는 애니메이션 한 번. 같은 종류를 연달아 눌러도 매번 새 `id`라 다시 튄다
- `Action` (taxonomy)
  - `view(View)` — `onAppear` · `backButtonTapped` · `downloadButtonTapped` ·
    `reactionTapped(ReactionKind)` · `photoSelected(Photo.ID?)` · `adjacentPhotoRequested(offset:)`
  - `delegate(Delegate)` — parent(App)와의 유일한 통신 채널
  - 내부 — `photosResponse(Result<[Photo], PhotoError>)` · `reactionSucceeded` ·
    `reactionFailed(photoID:userID:addedSticker:PhotoError)` · `saveSucceeded` · `saveFailed(PhotoError)`
  - `alert(PresentationAction<Alert>)` — `Alert.retryButtonTapped`(목록 조회 실패에만) ·
    `Alert.openSettingsButtonTapped`(권한 거부일 때만)

### Delegate 계약 (parent가 수신)

- `closeRequested` — 뒤로가기를 눌렀다. 실제로 화면을 닫는 것은 App의 몫이다

### 동작 규칙

- **리액션은 펼친 사진 한 장씩 지연 조회한다.** 목록엔 리액션이 없어, 진입·스와이프로 사진을 펼칠 때 그 한 장만
  `fetchPhotoReactionsUseCase`로 받아 병합한다(안 본 사진은 요청 안 함 → 1+N 회피). 한 번 받으면 `reactionsLoaded`에
  캐시해 다시 펼쳐도 재요청하지 않고, 그 사이 사용자가 그 사진에 리액션하면 진행 중이던 조회 결과가 낙관 상태를 덮지 않는다
- **이모지는 인당 무제한**으로 남긴다(정책 #71). 탭할 때마다 서버에 기록하고 이모지 쏟아지는 애니메이션(`reactionBurst`)을 튀운다
- **스티커는 유저당 첫 이모지 하나뿐.** 그 유저의 첫 이모지일 때만 스티커를 낙관적으로 붙이고(`addingReaction`),
  이미 스티커가 있으면 화면은 그대로 둔다(나머지 이모지는 채팅 히스토리로만 쌓인다)
- 서버가 갱신 사진을 주지 않아 **성공 응답은 낙관적 상태를 그대로 두고 재조회하지 않는다.** 실패하면
  방금 낙관적으로 붙인 스티커(`addedSticker`)만 되돌린다 — 이미 스티커가 있던 유저면 되돌릴 게 없다
- 저장은 진행 중 중복 탭을 무시한다(`isSaving` 가드). 저장하는 동안 화면에 딤 + 스피너 오버레이를 얹는다
  (원본을 통째로 받는 경로라 셀룰러에서 수 초가 걸린다). 권한이 거부되면 얼럿에 "설정으로 이동" 버튼이 붙는다
- 저장 성공 얼럿은 임의 작성본이다 — 시안에 완료 표현이 없어 토스트 시안이 나오면 교체한다
- 목록 조회 실패 얼럿에만 "다시 시도"가 붙는다. 리액션·저장은 화면의 버튼을 다시 누르면 된다
- 목록에 없는 사진으로는 넘어가지 않는다 (전환 도중 목록이 갈릴 때 방어)

### `StickerLayout` · `StickerPlacement`

- `StickerLayout.placements(for: Photo) -> [(reaction:placement:)]` — 유저별 스티커를 겹치지 않는 자리에 배정한다.
  처음 남긴 순서를 유지해 **먼저 남긴 3명(`maxCount`)까지만** 자리를 받고, 배정된 자리는 State에 저장돼 유지된다
- `StickerPlacement` — `xRatio` · `yRatio` · `angleDegrees` (사진 크기와 무관한 비율)
- **도메인이 아니라 여기 있는 이유** — 격자·비워 두는 구간·기울기가 전부 시안 실측이고 서버는 좌표를 주지 않는다.
  순수 계산이라 뷰가 아닌 `Sources/Support/`에 둔다

### `PhotoDetailView` (SwiftUI, `@ViewAction(for: PhotoDetailFeature.self)`)

- `init(store: StoreOf<PhotoDetailFeature>)` — App/Demo가 Store를 만들어 주입한다
- 구성: 배경(`Background.surface` + 하단 테마색 글로우) → `CHALLATopNavigation.sub`(뒤로가기 · 다운로드)
  → 사진 캐러셀 + 점 표시 → 리액션 바 → 채팅 입력창(모양만)
- `CHALLATopNavigation`을 실제 화면에서 쓰는 첫 사례다. 컴포넌트에 배경이 없어 화면이 `Background.surface`를
  깔고, 시스템 내비게이션 바는 `.toolbar(.hidden, for: .navigationBar)`로 숨긴다
- 하위 컴포넌트는 전부 internal — `PhotoCard` · `PhotoAuthorHeader` · `PhotoPageIndicator` ·
  `ReactionBar` · `ReactionSticker` · `ReactionBurstView`(이모지 쏟아지는 애니메이션 — `reactionBurst.id`로 매번 재생)
  (`Sources/Components/`에 뷰만 둔다)
- 색·타이포·둥글기는 DS 토큰만 쓴다 (원시 hex·Font.custom 없음)
- 점 표시는 최대 5개까지만 그린다 — 장수만큼 늘리면 사진이 쌓였을 때 화면 폭을 넘긴다
- 리액션 바는 칩(58) 사이를 `Spacer`로 균등 분배한다 — 간격을 고정하면 375pt 기기(SE 3세대·13 mini)에서
  양 끝 칩이 잘린다. 390pt(시안 기기)에서는 간격이 13이 된다
- 사진이 0장이고 로딩도 끝났으면 빈 카드에 안내 문구를 얹는다 (시안에 빈 상태가 없어 임시 문구)
- VoiceOver: 사진은 "{닉네임}님이 {시각}에 찍은 사진"으로 읽고, 페이지 TabView가 주지 않는 이동 수단은
  "이전/다음 사진" 액션으로 연다. 동작 없는 입력창은 `.accessibilityHidden(true)`로 숨긴다

### 알려진 제약

- **이미지 로딩은 DS의 `CHALLAAsyncImage`다**(#43) — 뷰 크기에 맞춰 다운샘플하고 2단 캐시(`CHALLAImageKit` #25)를
  태운다. 사진 카드(`PhotoCard.image`)와 아바타(`PhotoAuthorHeader`) 둘 다 이 뷰를 쓴다
- **리액션 이모지는 시스템 글리프**다. Figma는 Noto Color Emoji 벡터를 쓰므로 검수에서 차이가
  확인되면 SVG 에셋으로 바꾼다
- **눌린 리액션 칩의 모습이 없다** — 시안에 선택 상태 variant가 없어 색·테두리를 임의로 만들지 않았다.
  지금은 VoiceOver의 선택 상태로만 구분되고, 눈으로는 사진 위 스티커가 그 역할을 한다
- **스티커는 사진에 붙은 리액션 전부를 그린다** — 시안에는 한 개짜리 예시만 있어 여러 개가 붙는 규칙은
  클라이언트가 정했다. `StickerLayout`이 3 × 3 슬롯으로 나눠 배정하므로 9개까지 겹치지 않고,
  사진 위쪽 22%(촬영자 표시 자리)는 비운다. 10개째부터는 앞 슬롯에 다시 쌓인다
- 리액션 칩의 backdrop blur(Figma 12)는 재현하지 않았다. 배경이 어두운 화면이라 `Material.floating`
  단색으로도 시안과 큰 차이가 없다

## 의존성

- **이 모듈이 의존**: `PhotoDomain`(엔티티 · `PhotoError` · UseCase 키 3개) ·
  `ComposableArchitecture`(TCA 1.26) · `CHALLADesignSystem`(토큰 · 탑 내비 · 아바타)
- **이 모듈에 의존**: `PhotoDetailFeatureDemo` (앞으로 `CHALLAApp` — 이 화면을 push할 `RoomDetailFeature`가
  아직 없어 실배포앱 배선은 후속 이슈다)

## 테스트 실행 방법

```bash
mise exec -- tuist test PhotoDetailFeature
```

Swift Testing 35개, 다섯 묶음 (앞의 셋은 TCA `TestStore` 기반):

- `PhotoDetailPhotoTests` — 진입 → 조회 → 첫 장(또는 지정한 장) 펼침, 지정한 장이 없으면 첫 장으로 떨어짐,
  보던 사진이 재조회에서 사라지면 첫 장으로, 조회 실패 → "다시 시도"로 재조회, 사진 0장,
  사진 넘기기·목록에 없는 사진 무시·VoiceOver 이동(끝에서 멈춤)
- `PhotoDetailReactionTests` — 낙관적 갱신 후 서버 응답으로 교체, 켜기/끄기 요청값, 실패 시 되돌리기,
  되돌릴 때 그 사이 들어온 남의 리액션 보존, 응답 대기 중 재탭 무시(요청 1회), 다른 사진으로 옮겨도
  앞선 요청이 끊기지 않음, 사라진 사진을 응답이 되살리지 않음, 펼친 사진 없으면 무시,
  **같은 사진에 다른 종류를 연달아 눌렀을 때 먼저 온 응답이 대기 중인 스티커를 지우지 않음**(병합)
- `PhotoDetailSaveTests` — 저장 성공 얼럿, 권한 거부 시 설정 이동 얼럿, 권한 외 실패는 버튼 없음,
  설정 이동 시 `openURL` 호출, 저장 중 중복 탭에도 요청 1회, 뒤로가기 → `delegate.closeRequested`
- `StickerLayoutTests` — 같은 사진이면 같은 자리, 입력이 갈리면 자리도 갈림, **한 사진에 종류를 다 눌러도
  겹치지 않음**(사진 50장 × 조합 10개), 여러 사람이 같은 종류를 남겨도 겹치지 않음, 촬영자 표시를 가리지 않음,
  사진 밖으로 나가지 않음, 슬롯이 모자라면 앞자리에 쌓임
- `PhotoPageIndicatorTests` — 점 표시 창 계산: 장수가 최대치 이하면 전부, 넘으면 5개로 고정,
  현재 장을 가운데 두되 양 끝에서는 가장자리에 붙음, 사진 0장이면 빈 창

데모앱으로 화면을 직접 볼 때:

```bash
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state default
```

`--state`는 `default` · `loading` · `empty` · `error`. 인자가 없으면 상태를 고르는 목록이 뜬다.
