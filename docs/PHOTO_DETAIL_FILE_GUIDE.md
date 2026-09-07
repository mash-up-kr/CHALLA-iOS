# 사진 상세 화면 (#36) — 코드 안내서

`feat/#36-photo-detail` 브랜치가 추가·수정한 코드를 **파일 하나씩** 설명한다.

각 파일마다 세 가지를 적었다.

1. **왜 필요한가** — 이 파일이 없으면 무슨 일이 생기는지
2. **무엇을 하는가** — 코드와 줄별 해설
3. **함정** — 코드만 읽어서는 안 보이는 것

모듈의 공개 API 요약은 각 모듈의 `MODULE.md`에 있다. 이 문서는 그보다 아래, 구현 판단을 다룬다.
읽기용 문서라 PR에 넣기 싫으면 지워도 된다.

> **작성 시점 기준 문서다.** 아래 본문의 파일별 줄 수·코드 인용은 최초 구현 시점의 것이라 이후 갱신을 보장하지 않는다.
> 최신 사양은 언제나 각 모듈의 `MODULE.md`와 코드가 기준이다. 리뷰 반영으로 바뀐 부분은 바로 아래에 모아 둔다.

## 리뷰 반영 (2026-08-12)

main(#25 CHALLAImageKit · #43 CHALLAAsyncImage · #33 PhotoLibrary)을 머지하고 리뷰 지적을 반영했다.
아래 항목은 본문 설명과 다르다 — **여기가 최신이다.**

- **이미지 로딩** — 사진 카드·아바타가 시스템 `AsyncImage` → DS `CHALLAAsyncImage`(다운샘플 + 2단 캐시)
- **리액션 바** — 간격 13 고정 → `Spacer` 균등 분배 (375pt 기기에서 양 끝 칩이 잘리던 문제)
- **리액션 성공 응답** — 서버 사진으로 통째 교체하지 않고, 같은 사진에 아직 대기 중인 다른 종류의
  낙관적 리액션은 병합해 유지 (연달아 누르면 먼저 온 응답이 방금 붙인 스티커를 지우던 문제)
- **저장 중 표시** — `isSaving` 동안 화면에 딤 + 스피너 오버레이 (이전엔 표시가 없었다)
- **빈 상태** — 사진 0장 + 로딩 종료 시 안내 문구
- **스티커 배치** — `reaction.id`로 정렬해 서버가 목록 순서를 바꿔도 자리가 고정된다
- **Core/PhotoLibrary** — main의 권한 모듈(`.readWrite`)과 이 브랜치의 저장(`.addOnly`)이 한 모듈에 공존.
  두 접근 수준 구분은 `Projects/Core/PhotoLibrary/MODULE.md`에 정리
- **데모** — `_printChanges` 제거, 뒤로가기가 실제로 닫히도록 얇은 parent(`DemoDetailFeature`)를 둠
- **테스트** — 30개 → 35개 (리액션 병합 1 · 점 표시 창 계산 4)

코드로 바꾸지 않고 남겨 둔 판단:

- 리액션 칩 `Material.floating`은 원시 hex 유지 — 같은 팔레트 `dimmer`도 hex라 floating만 바꾸면 오히려 불일치
- `CHALLARadius.xxlarge`(44.5) 이름 — 스케일이 아니라 실측값이라 DS 담당자와 명명 규칙 논의 대상
- `PhotoError.userMessage` 다국어화 위치 — 문구 가이드 확정 시 재검토
- 촬영자 시각 `ko_KR`·24시간제 고정 — 시안 표기 확정값이라 유지

## 목차

- [0. 먼저 알아야 할 것](#0-먼저-알아야-할-것)
- [0-4. 무엇을 어디에 두는가](#0-4-무엇을-어디에-두는가)
- [1. 이 화면이 하는 일](#1-이-화면이-하는-일)
- [2. 데이터가 흐르는 세 가지 길](#2-데이터가-흐르는-세-가지-길)
- [3. PhotoDomain — 규칙](#3-photodomain--규칙)
- [4. Core/PhotoLibrary — 사진첩](#4-corephotolibrary--사진첩)
- [5. PhotoDetailFeature — 화면 로직](#5-photodetailfeature--화면-로직)
- [6. PhotoDetailFeature — 뷰](#6-photodetailfeature--뷰)
- [7. PhotoDetailFeatureDemo — 조립과 검증](#7-photodetailfeaturedemo--조립과-검증)
- [8. 테스트 — 무엇을 막고 있나](#8-테스트--무엇을-막고-있나)
- [9. 디자인 시스템·빌드 설정 변경분](#9-디자인-시스템빌드-설정-변경분)
- [10. 용어 사전](#10-용어-사전)
- [11. 실행과 검증](#11-실행과-검증)
- [12. 남은 일](#12-남은-일)

---

## 0. 먼저 알아야 할 것

### 0-1. 모듈을 왜 이렇게 쪼갰나

한 화면을 만드는 데 모듈이 넷이다. 처음 보면 과해 보이는데, 각각 **바뀌는 속도와 이유가 다르다.**

```
PhotoDetailFeatureDemo   앱      이 화면만 띄워 보는 검증용 앱
PhotoDetailFeature       Feature 화면 로직 + 뷰
PhotoDomain              Domain  사진·리액션의 규칙 (서버가 바뀌어도 그대로)
Core/PhotoLibrary        Core    사진첩 저장 (OS API 래핑)
```

의존 방향은 한쪽으로만 흐른다.

```
PhotoDetailFeatureDemo ─┬─→ PhotoDetailFeature ─┬─→ PhotoDomain
  (조립 지점)           ├─→ PhotoDomain          ├─→ ComposableArchitecture
                        └─→ Core/PhotoLibrary    └─→ CHALLADesignSystem
```

**핵심은 화살표가 없는 쪽이다.**

- `PhotoDetailFeature`는 서버도 사진첩도 모른다. `PhotoDomain`이 정의한 UseCase 3개만 본다
- `PhotoDomain`은 누구도 모른다. `Foundation` + 의존성 주입 매크로가 전부다
- `Core/PhotoLibrary`는 도메인을 모른다. Photos 프레임워크만 안다

이렇게 두면 얻는 게 세 가지다.

| 얻는 것 | 구체적으로 |
| :-- | :-- |
| **테스트 속도** | `PhotoDomain` 18개 테스트가 0.1초에 끝난다. 시뮬레이터도, 네트워크도 필요 없다 |
| **서버 변경 격리** | 서버 응답 모양이 바뀌면 `PhotoData`(아직 없음)만 고친다. 화면 코드는 그대로 |
| **화면 단독 검증** | 실앱(`CHALLAApp`)이 완성되기 전에도 데모앱으로 이 화면만 띄워 본다 |

이 규칙들은 내가 정한 게 아니라 `.claude/rules/architecture.md`의 6대 규칙이다. 이번 작업에 걸리는 건 세 개다.

- **규칙 1** `Feature → Domain ← Data` — Data가 Domain의 인터페이스를 구현한다
- **규칙 2** Feature는 Data를 import하지 않는다 — `@Dependency`로 주입받는다 (데모앱만 예외)
- **규칙 3** Feature끼리 직접 참조하지 않는다 — 화면 전환은 App이 조립한다

### 0-2. TCA 최소 지식

이 화면은 TCA(The Composable Architecture)로 썼다. 처음이라면 네 단어만 알면 읽을 수 있다.

| 단어 | 뜻 | 이 화면의 예 |
| :-- | :-- | :-- |
| **State** | 화면이 기억하는 값 전부 | 사진 목록, 지금 보는 사진, 로딩 중인지 |
| **Action** | 일어난 일 | "다운로드 버튼을 눌렀다", "목록 조회가 끝났다" |
| **Reducer** | Action을 받아 State를 바꾸고, 필요하면 Effect를 돌려주는 함수 | `PhotoDetailFeature.body` |
| **Effect** | 바깥 세상과의 대화 (네트워크·파일·타이머) | 사진 목록 조회, 사진첩 저장 |

**중요한 제약 하나** — State를 바꾸는 곳은 Reducer 안뿐이다. 뷰도, Effect 클로저도 State를 직접 못 만진다.
Effect는 일이 끝나면 "이런 결과가 나왔다"는 **Action을 다시 보낸다**. 그래서 코드에 `.photosResponse(...)` 같은
내부 Action이 있는 것이다.

이 규칙 덕분에 화면 로직을 시뮬레이터 없이 테스트할 수 있다 — TestStore에 Action을 넣고 State가 예상대로
바뀌는지 보면 된다. 이 브랜치 테스트 23개가 전부 그 방식이다.

### 0-3. 파일 지도

| 모듈 | 파일 | 줄 수 | 위치 |
| :-- | --: | --: | :-- |
| PhotoDomain | 17 | 585 | `Projects/Photo/PhotoDomain/` |
| Core/PhotoLibrary | 3 | 44 | `Projects/Core/PhotoLibrary/` |
| PhotoDetailFeature | 16 | 1,674 | `Projects/Photo/PhotoDetail/PhotoDetailFeature/` |
| PhotoDetailFeatureDemo | 8 | 330 | `Projects/Photo/PhotoDetail/PhotoDetailFeatureDemo/` |

디자인 시스템 5개 파일 수정 + 아이콘 1개 신규, 빌드 헬퍼 1개 수정이 더 있다.

---

## 0-4. 무엇을 어디에 두는가

레이어를 나눴으면 "이 코드는 어느 층인가"를 매번 판단해야 한다. 이 브랜치가 쓴 기준은 다음 다섯 줄이다.

| 층 | 두는 기준 | 이 브랜치의 예 |
| :-- | :-- | :-- |
| **Domain** | 서버·화면이 바뀌어도 남는 규칙과 계약 | `Photo` · `PhotoReaction` · `settingReaction` · `PhotoRepository` |
| **Core** | OS를 만지는 것 | `PhotoLibraryStore` (Photos 프레임워크) |
| **Feature** | 시안 수치 · 표시 규칙 · 화면 상태 | `StickerLayout` · `ReactionKind+Emoji` · 리듀서 · 뷰 |
| **App(데모)** | 조립과 번역 | `CompositionRoot` · `PhotoLibraryAdapter` |
| **디자인 시스템** | 두 화면 이상이 쓰는 토큰·컴포넌트 | `Material.floating` · `CHALLARadius.xxlarge` · `DownloadSimple` |

판단이 갈렸던 여섯 가지는 이렇게 정리했다.

| 항목 | 결정 | 근거 |
| :-- | :-- | :-- |
| **스티커 배치** | Domain → **Feature로 옮김** | 격자·비워 두는 구간·기울기가 전부 시안 실측이다. 도메인이 "위쪽에 촬영자 이름이 얹힌다"를 알 이유가 없다 |
| `PhotoError.userMessage` | Domain 유지 | 표시 문구가 도메인에 있는 건 어색하지만 `AuthError`가 같은 방식이다. 문구 정책이 정해지면 두 모듈을 함께 옮긴다 |
| 이모지 글리프 | Feature | 도메인은 "무슨 뜻의 리액션인가"(`.clap`)만, 화면이 "어떻게 보이나"(`"👏"`)를 안다 |
| 사진첩 저장 | 인터페이스 Domain · 구현 Core · 어댑터 App | `Keychain` ← `TokenStore` ← `KeychainTokenStore`와 같은 삼단 구조. Core는 도메인을 모른다 |
| `ReactionSticker` · `ReactionBar` | DS 아님 | 이 화면 전용이다. 두 번째 사용처가 생기면 그때 올린다 (`CHALLAAvatar`가 그렇게 올라왔다) |
| 테스트 픽스처 중복 | 유지 | `PhotoFixture`(Domain)와 `Fixture`(Feature)는 타깃이 다르다. 공유하려면 별도 TestSupport 모듈이 필요해 지금은 과하다 |

파일 안 배치도 두 가지 규칙을 따랐다.

- `Sources/Components/`에는 **SwiftUI 뷰만** 둔다. 순수 계산(`StickerLayout`)과 표시 규칙(`ReactionKind+Emoji`)은 `Sources/` 루트로
- **타입 하나에 파일 하나** — `StickerPlacement`와 `DemoPhotoStore`를 각자 파일로 뺐다 (`KeychainError`를 분리한 리뷰 선례)

---

## 1. 이 화면이 하는 일

사용자가 보는 것부터 정리하면 코드 읽기가 쉬워진다.

```
┌─────────────────────────────┐
│  ‹   해피하우스 강릉 여행   ⤓ │  탑 내비게이션 (뒤로가기 · 다운로드)
├─────────────────────────────┤
│      🙍 나는야멋쟁이토마토    │  촬영자 (사진 위에 얹힘)
│      2026. 7.16. 14:34      │
│                             │
│         [ 사 진 ]      👏    │  좌우 스와이프로 넘김, 리액션은 스티커로
│                             │
├─────────────────────────────┤
│        ● ○ ○ ○ ○            │  현재 몇 번째인지
│                             │
│   🏅  ❤️  💩  👏  💀         │  리액션 5종
│                             │
│  [ 이 사진에 메시지를... ]    │  채팅 입력창 (모양만 — 후속 이슈)
└─────────────────────────────┘
```

동작은 네 가지다.

1. **진입하면 방의 사진을 받아온다** — 실패하면 "다시 시도" 얼럿
2. **좌우로 넘긴다** — 점 표시가 따라 움직인다
3. **리액션을 남긴다/지운다** — 누르는 즉시 스티커가 사진에 붙고, 서버 응답은 나중에 확인
4. **사진첩에 저장한다** — 권한 팝업 → 저장, 거부되면 설정으로 보내는 얼럿

채팅은 이번 범위가 아니다. 시안에 입력창이 있어서 **모양만** 그렸다.

---

## 2. 데이터가 흐르는 세 가지 길

### 2-1. 화면 진입 → 사진 목록

```
PhotoDetailView
  .onAppear → send(.onAppear)
        │
        ▼
PhotoDetailFeature.body
  case .view(.onAppear) → loadPhotos(&state)
        │  state.isLoading = true          ← 화면에 스피너
        ▼
Effect .run
  fetchRoomPhotosUseCase.run(roomID)
        │
        ▼
FetchRoomPhotosUseCase.live(repository:)   ← 데모의 CompositionRoot가 주입
        │
        ▼
DemoPhotoRepository.photos(inRoom:)        ← 실제로는 PhotoData가 될 자리
        │
        ▼ (결과)
send(.photosResponse(.success(photos)))
        │
        ▼
PhotoDetailFeature.body
  state.isLoading = false
  state.apply(photos:)                      ← 목록 교체 + 볼 사진 결정
        │
        ▼
PhotoDetailView가 자동으로 다시 그려진다     ← @ObservableState
```

여기서 화면은 `DemoPhotoRepository`의 존재를 모른다. `\.fetchRoomPhotosUseCase`라는 **이름표**만 알고,
그 자리에 무엇이 꽂히는지는 앱이 정한다. 테스트에서는 여기에 "항상 실패하는 함수"를 꽂아 실패 경로를 검사한다.

### 2-2. 리액션 탭 (낙관적 갱신)

```
👏 탭 → send(.reactionTapped(.clap))
        │
        ▼
setReaction(&state, kind: .clap)
  ① 이미 진행 중인 (사진, 종류)면 무시
  ② isOn = 지금 안 눌려 있으니 true
  ③ inFlightReactions에 잠금 표시
  ④ state.photos[id:] = photo.settingReaction(.clap, by: 나, isOn: true)
        │                └── 서버 응답을 기다리지 않고 화면부터 바꾼다
        ▼
Effect .run → setPhotoReactionUseCase.run(photoID, .clap, true)
        │
   ┌────┴────┐
 성공        실패
   │           │
   ▼           ▼
reactionSucceeded          reactionFailed(appliedIsOn: true)
  잠금 해제                  잠금 해제
  서버 사진으로 교체          settingReaction(..., isOn: false)로 되돌림
                            + "리액션을 남기지 못했어요" 얼럿
```

**낙관적 갱신(optimistic update)이란** 서버 응답을 기다리지 않고 화면을 먼저 바꾸는 방식이다.
안 하면 이모지를 누르고 0.5초 뒤에야 스티커가 붙어 굼떠 보인다. 대신 실패했을 때 되돌리는 책임이 생긴다.

### 2-3. 다운로드 → 사진첩

```
⤓ 탭 → send(.downloadButtonTapped)
        │
        ▼
savePhoto(&state)   isSaving = true (중복 탭 차단)
        │
        ▼
savePhotoUseCase.run(photo)
        │
        ├─→ repository.imageData(for:)      URL에서 바이트 내려받기
        └─→ photoLibrary.save(imageData:)   사진첩에 쓰기
                    │
                    ▼
              PhotoLibraryAdapter (데모의 CompositionRoot)
                    │  PhotoLibraryError → PhotoError 번역
                    ▼
              PhotoLibraryStore (Core)
                    │  권한 요청 → PHAssetCreationRequest
                    ▼
              시스템 사진첩
```

이 경로가 **모듈 넷을 모두 지나간다.** 각 층이 무슨 일을 맡는지 보기 좋은 예다.

- Feature: "저장해 달라"는 의도와 버튼 잠금
- Domain: "내려받고 → 쓴다"는 순서와 오류 정규화
- Core: OS 권한과 Photos API
- Demo(조립 지점): Core의 오류를 Domain의 오류로 번역

---

## 3. PhotoDomain — 규칙

`Projects/Photo/PhotoDomain/`

이 모듈에는 화면도, 서버도, 사진첩도 없다. **"사진과 리액션은 이런 것이다"라는 약속**만 있다.

### 3-1. Project.swift (8줄)

```swift
let project = Project.makeModule(
    name: "PhotoDomain",
    hasTests: true,
    dependencies: [.dependencies, .dependenciesMacros] // swift-dependencies (TCA 전이 의존)
)
```

**왜 필요한가** — Tuist가 이 폴더를 Xcode 타깃으로 만드는 설계도다.

**설명** — `hasTests: true`가 `PhotoDomainTests` 타깃을 함께 만든다. 의존성 두 개는 TCA가 딸려오게 하는
`swift-dependencies`인데, UseCase가 `@DependencyClient` 키를 선언하는 데만 쓴다. TCA 본체(`ComposableArchitecture`)는
넣지 않았다 — Domain은 리듀서를 모른다.

**함정** — `AuthDomain`은 이 헬퍼 없이 Project를 손으로 구성했다(이슈 #8 이전 방식). 새 모듈은 이 한 줄이 정답이다.

### 3-2. Sources/Entities/Photo.swift (65줄)

**왜 필요한가** — 화면·서버·테스트가 "사진"이라는 말을 같은 뜻으로 쓰게 하는 기준점이다.
이게 없으면 각자 딕셔너리나 튜플로 들고 다니게 되고, 필드 이름이 갈리기 시작한다.

```swift
public struct Photo: Identifiable, Sendable, Equatable {
    public let id: String
    public let imageURL: URL
    public let author: PhotoAuthor
    public let capturedAt: Date
    /// 한 사람이 종류별로 하나씩 남긴다.
    public let reactions: [PhotoReaction]
```

전부 `let`이다 — 값이 바뀌면 새 `Photo`를 만든다. TCA State는 값 타입이어야 변경 추적이 되기 때문이다.

**중복 제거가 `init`에 있다.**

```swift
// 서버가 중복으로 줘도 화면에는 하나만 남긴다 (스티커 겹침 · 리액션 id 충돌 방지).
var seen = Set<PhotoReaction.ID>()
self.reactions = reactions.filter { seen.insert($0.id).inserted }
```

`Set.insert`는 `(inserted: Bool, memberAfterInsert:)`를 돌려준다. 처음 보는 id면 `inserted == true`라 통과하고,
두 번째부터는 걸러진다. `contains(where:)`를 매번 도는 방식보다 빠르고(O(n) vs O(n²)) 두 줄이다.

**왜 여기서 막나** — 서버가 같은 사람의 같은 리액션을 두 번 주면 ① 스티커가 정확히 같은 자리에 겹쳐 그려지고
② SwiftUI `ForEach`의 id가 충돌해 렌더가 깨진다. 화면마다 방어하는 대신 **타입이 스스로 불변식을 지키게** 했다.

**메서드 두 개**

```swift
public func hasReaction(_ kind: ReactionKind, by userID: String) -> Bool

public func settingReaction(_ kind: ReactionKind, by userID: String, isOn: Bool) -> Photo {
    var next = reactions.filter { !($0.kind == kind && $0.userID == userID) }
    if isOn {
        next.append(PhotoReaction(kind: kind, userID: userID))
    }
    return Photo(id: id, imageURL: imageURL, author: author, capturedAt: capturedAt, reactions: next)
}
```

한 줄로 읽으면 "그 사람의 그 종류를 일단 다 빼고, 켜는 거면 하나 넣는다"이다.

**왜 toggle이 아니라 `isOn`을 받나** — 이게 이 파일에서 가장 중요한 결정이다.

| 방식 | 두 번 적용하면 | 롤백할 때 |
| :-- | :-- | :-- |
| `togglingReaction(kind:by:)` | 원래대로 돌아간다 (위험) | "지금 상태"를 알아야 한다 |
| `settingReaction(kind:by:isOn:)` | **결과가 같다** (멱등) | 반대 값만 넣으면 끝 |

낙관적 갱신은 "내가 화면에 뭘 그렸는지"를 기억했다가 실패 시 되돌린다. 목표 상태를 받는 형태여야
그 되돌리기가 안전하다. 리듀서의 `reactionFailed`가 `isOn: !appliedIsOn` 한 줄로 끝나는 이유다.

### 3-3. Sources/Entities/PhotoAuthor.swift (15줄)

```swift
/// 사진을 찍은 사람. `UserDomain`의 프로필과 별개로, 사진에 박제된 시점의 정보다.
public struct PhotoAuthor: Sendable, Equatable {
    public let id: String
    public let nickname: String
    public let avatarURL: URL?
}
```

**왜 필요한가 / 왜 UserDomain의 프로필을 안 쓰나** — 사진은 "그때 그 사람이 찍은 것"이다. 나중에 닉네임을
바꿔도 예전 사진의 표시를 어떻게 할지는 제품 결정이고, 서버가 사진 응답에 촬영자 정보를 함께 실어 주는 게
보통이다. 별도 타입으로 두면 유저 도메인이 생겨도 이 화면은 영향받지 않는다.

`avatarURL`만 옵셔널이다 — 프로필 사진은 없을 수 있고, 그때는 기본 아바타를 그린다.

### 3-4. Sources/Entities/PhotoReaction.swift (21줄)

```swift
public struct PhotoReaction: Sendable, Hashable, Identifiable {
    public let kind: ReactionKind
    public let userID: String

    public var id: String { "\(userID)-\(kind.rawValue)" }
}
```

**왜 필요한가** — "누가 어떤 리액션을 남겼는가"를 한 덩어리로 묶는다.

**스티커 자리를 여기 두지 않는다.** 처음에는 `placement`를 들고 있었는데, 그러면 리액션이 자기 자리를
혼자 정하게 되고 **옆 스티커를 몰라서 포개진다.** 자리는 사진 전체를 보는 `Photo.stickerPlacements`가 정한다.

**id 규칙이 핵심이다.** 한 사람이 같은 종류를 두 번 남길 수 없으므로 `종류 + 사람`이 곧 신원이다.
이 한 줄이 세 곳에서 일한다.

1. `Photo.init`의 중복 제거 기준
2. `PhotoCard`의 `ForEach(photo.reactions)` — `Identifiable`이라 id 지정이 필요 없다
3. 리듀서의 `ReactionRequest`(사진+종류)와 짝이 맞는다

**함정** — 초기 구현은 `ForEach(photo.reactions, id: \.self)`였다. 값 전체가 id라서, 서버가 중복을 주면
id가 충돌한다. 코드 리뷰에서 잡혀 `Identifiable`로 바꿨다.

### 3-5. Sources/Entities/ReactionKind.swift (12줄)

```swift
public enum ReactionKind: String, Sendable, Equatable, CaseIterable {
    case medal, heart, poop, clap, skull   // 실제 파일은 한 줄에 하나씩
}
```

**왜 필요한가** — 리액션 종류를 문자열로 들고 다니면 오타가 런타임까지 살아남는다. enum이면 컴파일러가 막는다.
`CaseIterable`이라 뷰가 `ReactionKind.allCases`로 5개 버튼을 자동으로 그린다 — 종류가 늘어도 뷰는 그대로다.

**이모지를 여기 두지 않은 이유** — `"👏"`는 표시 방식이지 도메인 지식이 아니다. 나중에 디자인이 이모지 대신
커스텀 일러스트를 쓰기로 하면 도메인이 흔들린다. 그래서 글리프는 Feature의 `ReactionKind+Emoji`에 있다.

`rawValue`(medal, heart…)는 서버와 주고받을 값이라 도메인에 두는 게 맞다.

### 3-6. 이 모듈에 두지 않은 것 — 스티커 배치

스티커가 사진 위 어디에 붙는지는 **화면이 정한다**(`PhotoDetailFeature.StickerLayout`).
한때 `ReactionPlacement`로 이 모듈에 있었는데, 파일을 열어 보면 도메인이 아니라는 게 드러난다.

```swift
private static let top = 0.22      // 촬영자 표시가 얹히는 자리
static let jitterX = 0.035
static let angleLower = -20.0
```

전부 **시안 레이아웃 실측**(사진 358 × 477, 스티커 82, 촬영자 표시 32 + 48)에서 나온 값이다.
도메인 모듈이 "사진 카드 위쪽에 촬영자 이름이 얹힌다"를 알 이유가 없다.
서버가 좌표를 주기 시작하면 그때 `PhotoReaction`에 실어 도메인으로 들인다.

### 3-7. Sources/Errors/PhotoError.swift (35줄)

**왜 필요한가** — 오류 타입을 정하지 않으면 화면이 `URLError`·`PHPhotosError`·`DecodingError`를 다 알아야 한다.
그러면 규칙 2(Feature는 서버를 모른다)가 무너진다.

```swift
public enum PhotoError: Error, Equatable, Sendable {
    case network                    // 오프라인·타임아웃
    case server(message: String)    // 서버가 실패를 알림
    case permissionDenied           // 사진첩 권한 거부
    case saveFailed                 // 권한은 있는데 쓰기 실패
    case unknown

    public var userMessage: String { ... }
}
```

**다섯 개인 이유** — 화면이 **다르게 반응해야 하는 경우**만 나눴다.

- `permissionDenied`만 얼럿에 "설정으로 이동" 버튼이 붙는다
- `server(message:)`는 서버 문구를 그대로 보여준다
- 나머지는 문구만 다르다

`Equatable`이라 테스트에서 `#expect(throws: PhotoError.network)`로 정확히 비교할 수 있다.

**함정** — `userMessage`는 내가 임의로 쓴 문구다. `TODO`를 달아 뒀고, 기획의 에러 문구 가이드가 나오면
이 파일만 고치면 된다.

### 3-8. Sources/Interface/PhotoRepository.swift (16줄)

**왜 필요한가** — Domain이 "서버에서 이런 걸 가져올 수 있어야 한다"고 요구하고, 구현은 Data가 한다.
이 방향(의존성 역전) 때문에 Domain이 네트워크를 몰라도 된다.

```swift
public protocol PhotoRepository: Sendable {
    func photos(inRoom roomID: String) async throws -> [Photo]

    /// 리액션을 목표 상태로 맞추고 갱신된 사진을 돌려준다.
    /// 뒤집기가 아니라 멱등 형태인 이유는 재시도·취소가 안전해야 하기 때문이다.
    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool) async throws -> Photo

    func imageData(for photo: Photo) async throws -> Data
}
```

**`Sendable`인 이유** — Swift 6에서는 값이 스레드를 넘나들려면 컴파일러에게 안전을 증명해야 한다.
Repository는 Effect 안(다른 태스크)에서 호출되므로 필수다.

**`setReaction`이 갱신된 사진 전체를 돌려주는 이유** — 서버가 최종 상태의 소유자다. 내가 낙관적으로 그린 것과
서버 결과가 다를 수 있으므로(남이 동시에 리액션을 남겼다든지) 응답으로 통째 교체한다.

**계약** — 구현체는 실패를 전부 `PhotoError`로 정규화해 던진다. 문서가 아니라 진짜 계약이라,
`SavePhotoUseCase`에 이를 어겨도 새어 나가지 않게 막는 코드가 있다.

### 3-9. Sources/Interface/PhotoLibraryWriting.swift (7줄)

```swift
/// 기기 사진첩 쓰기 추상. 권한 요청까지 구현체 안에서 끝내고, 거부되면 `PhotoError.permissionDenied`를 던진다.
public protocol PhotoLibraryWriting: Sendable {
    func save(imageData: Data) async throws
}
```

**왜 필요한가** — `SavePhotoUseCase`가 "사진첩에 쓴다"를 표현해야 하는데, Domain이 Photos 프레임워크를
import할 수는 없다(Domain은 OS를 모른다). 그래서 이름만 정의하고 구현은 Core가 한다.

**왜 권한 요청까지 구현체 책임인가** — 권한 확인과 저장을 나누면 호출부가 순서를 지켜야 하고, 잊으면 크래시한다.
"저장해 달라"고만 하면 되게 묶었다.

### 3-10. Sources/UseCases/ — 3개

**왜 UseCase 층이 필요한가.** Feature가 Repository를 직접 쓰면 안 되나? 세 가지 이유로 한 겹을 뒀다.

1. **조립 로직의 자리** — `SavePhotoUseCase`는 "내려받고 → 쓴다" 두 단계다. 이걸 화면에 두면 화면이
   비대해지고, 다른 화면에서 같은 일을 하려면 복사해야 한다
2. **테스트 교체 지점** — 테스트는 `$0.savePhotoUseCase = SavePhotoUseCase(run: { _ in throw ... })` 한 줄로
   실패를 만든다. Repository를 직접 쓰면 프로토콜 전체를 구현한 Mock이 필요하다
3. **화면이 필요한 만큼만 노출** — Repository에는 메서드가 3개지만, 각 화면은 자기가 쓰는 UseCase만 안다

#### FetchRoomPhotosUseCase.swift (28줄) — 세 UseCase의 공통 골격

```swift
@DependencyClient
public struct FetchRoomPhotosUseCase: Sendable {
    public var run: @Sendable (_ roomID: String) async throws -> [Photo]
}

extension FetchRoomPhotosUseCase: TestDependencyKey {
    public static func live(repository: any PhotoRepository) -> FetchRoomPhotosUseCase {
        FetchRoomPhotosUseCase(run: { roomID in
            try await repository.photos(inRoom: roomID)
        })
    }

    public static let testValue = FetchRoomPhotosUseCase()
    public static let previewValue = FetchRoomPhotosUseCase(run: { _ in [] })
}

public extension DependencyValues {
    var fetchRoomPhotosUseCase: FetchRoomPhotosUseCase {
        get { self[FetchRoomPhotosUseCase.self] }
        set { self[FetchRoomPhotosUseCase.self] = newValue }
    }
}
```

- **`@DependencyClient`** — 프로토콜 대신 **구조체 + 클로저 프로퍼티**로 의존성을 만든다.
  테스트에서 클로저만 갈아끼우면 되고, 별도 Mock 클래스가 필요 없다
- **`testValue`** — 테스트에서 깜빡하고 주입하지 않은 UseCase를 호출하면 실패로 알려주는 기본값이다.
  `@DependencyClient`가 만들어 준다
- **`DependencyValues` 확장** — `@Dependency(\.fetchRoomPhotosUseCase)`로 꺼내 쓸 이름표를 등록한다

**`liveValue`가 없는 게 의도다.** 인자 없는 `liveValue`를 만들려면 Domain이 Data를 import해서 구현체를
직접 생성해야 하는데, 그러면 규칙 2가 깨진다. 대신 `live(repository:)` 팩토리를 두고 조립은 앱이 한다.
주입을 잊으면 런타임에 "no live implementation"이 뜬다 — 조용히 잘못 동작하는 것보다 낫다는 판단이며
`AuthDomain`도 같은 방식이다.

#### SetPhotoReactionUseCase.swift (26줄)

`run(photoID, kind, isOn)`을 Repository에 그대로 넘긴다. 조립할 게 없어 얇다.
얇아도 두는 이유는 위의 2번(테스트 교체 지점)과 3번(노출 최소화) 때문이다.

#### SavePhotoUseCase.swift (36줄)

셋 중 유일하게 두 단계를 조립한다.

```swift
public static func live(
    repository: any PhotoRepository,
    photoLibrary: any PhotoLibraryWriting
) -> SavePhotoUseCase {
    SavePhotoUseCase(run: { photo in
        do {
            let data = try await repository.imageData(for: photo)
            try await photoLibrary.save(imageData: data)
        } catch {
            // 구현체가 계약을 어기고 다른 오류를 던져도 Feature는 PhotoError만 받는다.
            guard error is PhotoError || error is CancellationError else { throw PhotoError.unknown }
            throw error
        }
    })
}
```

**왜 방어 코드를 두나** — "실패는 `PhotoError`로 정규화한다"는 계약을 구현체가 어길 수 있다.
계약 위반이 화면까지 올라오면 리듀서의 `catch`가 뜻 모를 오류를 받고, 사용자는 아무 반응 없는 버튼을 보게 된다.
여기서 한 번 걸러 두면 **화면은 `PhotoError`만 다루면 된다**는 전제가 항상 참이 된다.

**취소는 통과시킨다** — `CancellationError`는 "실패"가 아니라 "그만두라고 해서 그만뒀다"는 뜻이다.
이걸 `unknown`으로 바꿔 버리면 화면 이탈 시 뜬금없는 실패 얼럿이 뜬다.

---

## 4. Core/PhotoLibrary — 사진첩

`Projects/Core/PhotoLibrary/` — 44줄. 작지만 별도 모듈인 이유가 있다.

**왜 모듈로 분리했나** — 저장소 규칙이 "**OS를 만지면 Core**"다. Photos 프레임워크는 권한 팝업을 띄우고
기기 상태에 의존한다. 이런 코드를 Feature나 Data에 섞으면 그 모듈 전체가 시뮬레이터 없이는 테스트 불가가 된다.
격리해 두면 나머지는 순수하게 남는다.

### 4-1. Project.swift (6줄)

```swift
// 테스트 타깃을 두지 않는다 — 이 모듈의 코드는 전부 사진첩 권한 팝업과 시스템 사진첩 상태에
// 의존해서 유닛테스트로 고정할 만한 순수 로직이 없다. 동작 확인은 데모앱 실행으로 한다.
let project = Project.makeModule(name: "PhotoLibrary") // 외부 의존 0 (Photos는 시스템)
```

테스트 타깃이 없는 건 게으름이 아니라 판단이고, 그 판단을 주석과 MODULE.md에 남겼다.

### 4-2. Sources/PhotoLibraryStore.swift (27줄)

```swift
public struct PhotoLibraryStore: Sendable {

    public init() {}

    public func save(imageData: Data) async throws {
        // 이미 결정된 상태면 팝업 없이 그 값이 바로 돌아온다.
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.permissionDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                // 원본 바이트 그대로 — UIImage로 만들면 메타데이터가 날아가고 재인코딩된다.
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
            }
        } catch {
            throw PhotoLibraryError.saveFailed
        }
    }
}
```

한 줄씩:

- **`.addOnly`** — 사진첩 권한은 읽기(`.readWrite`)와 추가 전용(`.addOnly`)이 나뉜다. 우리는 저장만 하므로
  추가 전용이면 충분하고, 사용자에게 "사진 전체를 보겠다"고 묻지 않아도 된다. 팝업 문구도 덜 위협적이다
- **`.limited`도 통과** — 사용자가 "선택한 사진만 허용"을 골라도 추가는 가능하다
- **`performChanges`** — Photos 프레임워크에서 사진첩을 바꾸려면 이 블록 안에서 해야 한다. 실패는 던져진다
- **원본 바이트** — `UIImage(data:)`로 변환해 저장하면 EXIF(촬영 시각·기기 정보)가 날아가고 JPEG가 다시
  인코딩돼 화질이 떨어진다. `addResource(with:data:)`는 받은 바이트를 그대로 파일로 만든다

**왜 도메인 프로토콜을 채택하지 않나** — `PhotoLibraryWriting`을 여기서 채택하면 Core가 Domain을 알게 된다.
`Keychain` 모듈이 `TokenStore`를 모르고 `AuthData`의 `KeychainTokenStore`가 어댑터를 맡는 것과 같은 구조다.
지금은 `PhotoData`가 없어 데모의 `CompositionRoot`가 그 자리를 대신한다.

### 4-3. Sources/PhotoLibraryError.swift (11줄)

`permissionDenied` · `saveFailed` 두 개. 어댑터가 `PhotoError`로 번역한다.

**왜 Core에 자기 오류 타입이 있나** — Core가 `PhotoError`를 던지면 Domain에 의존하게 된다.
자기 언어로 던지고, 번역은 경계에서 한 번 한다.

> **꼭 기억할 것** — 이 모듈을 쓰는 앱의 Info.plist에 `NSPhotoLibraryAddUsageDescription`이 없으면
> 권한 요청 순간 앱이 **죽는다**(iOS 정책). 데모앱 `Project.swift`에 넣어 뒀고, 나중에 `CHALLAApp`에도 필요하다.

---

## 5. PhotoDetailFeature — 화면 로직

`Projects/Photo/PhotoDetail/PhotoDetailFeature/Sources/PhotoDetailFeature.swift` (314줄)

이 파일 하나가 화면의 두뇌다. 순서대로 본다.

### 5-1. State — 화면이 기억하는 것

```swift
@ObservableState
public struct State: Equatable {
    public let roomID: String
    public let roomTitle: String       // 탑 내비게이션 타이틀
    public let currentUserID: String   // 리액션을 남기는 주체

    public var photos: IdentifiedArrayOf<Photo> = []
    public var selectedPhotoID: Photo.ID?
    public var isLoading = false
    public var isSaving = false
    @Presents public var alert: AlertState<Action.Alert>?

    /// 응답을 기다리는 중인 리액션 — 같은 자리를 다시 눌러도 요청이 겹치지 않게 막는다.
    public var inFlightReactions: Set<ReactionRequest> = []

    /// 진입할 때 펼쳐 보여줄 사진.
    private let initialPhotoID: Photo.ID?
}
```

하나씩 왜 있는지:

| 프로퍼티 | 왜 필요한가 |
| :-- | :-- |
| `roomID` | 목록을 조회할 때 필요. 화면이 사는 동안 안 바뀌므로 `let` |
| `roomTitle` | 탑 내비 타이틀. 방 이름을 다시 조회하지 않으려고 받아 온다 |
| `currentUserID` | "내 리액션"을 가려내려면 내가 누군지 알아야 한다 |
| `photos` | 목록. **`IdentifiedArrayOf`**를 쓴 이유는 아래 |
| `selectedPhotoID` | 인덱스 대신 id로 기억한다. 목록이 갱신돼도 보던 사진을 따라갈 수 있다 |
| `isLoading` / `isSaving` | 화면 표시 + **중복 요청 차단** 두 가지 역할 |
| `alert` | `@Presents`는 TCA가 얼럿 생명주기를 관리하게 하는 표시 |
| `inFlightReactions` | 리액션은 여러 개가 동시에 떠 있을 수 있어 Bool 하나로는 부족하다 |
| `initialPhotoID` | 목록에서 특정 사진을 눌러 들어왔을 때 그 장을 펼치려고. private — 밖에서 읽을 일이 없다 |

**`IdentifiedArrayOf<Photo>`란** — 배열인데 id로도 접근할 수 있다(`photos[id: "photo-1"]`).
순서(캐러셀)와 id 접근(리액션 갱신)이 둘 다 필요해서 쓴다. 일반 배열이면 매번 `firstIndex(where:)`를 돌아야 한다.

**`apply(photos:)`**

```swift
/// 목록을 갈아끼우고 볼 사진을 정한다. 보던 사진이 사라졌으면 첫 장으로 떨어진다.
mutating func apply(photos: [Photo]) {
    self.photos = IdentifiedArray(uniqueElements: photos)
    let preferred = selectedPhotoID ?? initialPhotoID
    selectedPhotoID = preferred.flatMap { self.photos[id: $0]?.id } ?? photos.first?.id
}
```

목록 교체와 "무엇을 볼지"는 항상 같이 결정돼야 해서 한 함수에 묶었다. 우선순위는
**보던 사진 → 진입할 때 지정한 사진 → 첫 장**이다. `flatMap`으로 "새 목록에 그 id가 남아 있는지"를
확인하므로, 사진이 삭제된 경우 자동으로 첫 장으로 떨어진다.

### 5-2. ReactionRequest — 요청의 신원

```swift
/// 리액션 요청 하나의 신원. 사진과 종류가 다르면 서로 간섭하지 않는다.
public struct ReactionRequest: Hashable, Sendable {
    public let photoID: String
    public let kind: ReactionKind
}
```

**왜 필요한가** — 리액션 요청은 여러 개가 동시에 날아갈 수 있다(1번 사진에 👏 요청 중에 2번 사진으로 넘어가
❤️ 요청). 각각을 구분할 이름이 있어야 ① 중복 탭을 막고 ② 응답이 왔을 때 어느 요청인지 알고
③ 이펙트 취소 키를 나눌 수 있다.

### 5-3. Action — 일어날 수 있는 일

네 갈래로 나눈다. 저장소 표준 taxonomy다.

```swift
public enum Action: ViewAction, Sendable {
    public enum ViewAction: Sendable {       // ① 사용자가 한 일
        case onAppear
        case backButtonTapped
        case downloadButtonTapped
        case reactionTapped(ReactionKind)
        case photoSelected(Photo.ID?)
        case adjacentPhotoRequested(offset: Int)   // VoiceOver 이동
    }
    case view(ViewAction)

    @CasePathable
    public enum Delegate: Equatable, Sendable {    // ② 부모에게 알릴 일
        case closeRequested
    }
    case delegate(Delegate)

    case photosResponse(Result<[Photo], PhotoError>)          // ③ 내부 결과
    case reactionSucceeded(ReactionRequest, Photo)
    case reactionFailed(ReactionRequest, PhotoError, appliedIsOn: Bool)
    case saveSucceeded
    case saveFailed(PhotoError)

    public enum Alert: Equatable, Sendable {       // ④ 얼럿 버튼
        case retryButtonTapped
        case openSettingsButtonTapped
    }
    case alert(PresentationAction<Alert>)
}
```

**왜 이렇게 나누나** — Action 이름만 봐도 "누가 보낸 것인지"가 드러난다. 뷰가 보낼 수 있는 건 `view(...)`뿐이고,
내부 결과 Action을 뷰가 보낼 일은 없다. `@ViewAction` 매크로가 뷰에서 `send(.onAppear)`처럼 쓰게 해 준다.

**`delegate`가 하는 일** — 뒤로가기를 눌렀을 때 **이 화면은 자기를 닫지 않는다.** "닫아 달라"고 부모에게
알리기만 한다. 규칙 3(Feature끼리 직접 참조 금지) 때문이다. 이 화면이 어디서 열렸는지에 따라 닫는 방법이
다르므로(push였는지 sheet였는지) 그 지식은 조립하는 쪽에 있어야 한다.

**`saveSucceeded` / `saveFailed`가 `Result`가 아닌 이유** — 성공에 담을 값이 없다.
`Result<Void, PhotoError>`는 Equatable이 되지 않아 테스트에서 불편하다.

**`reactionFailed`가 `appliedIsOn`을 들고 다니는 이유** — 되돌리려면 "내가 뭘 그렸는지"를 알아야 한다.
사진 스냅샷을 통째로 들고 다니는 방법도 있었지만(초기 구현) 그러면 그 사이 들어온 다른 변화까지 덮어쓴다.

### 5-4. Reducer 본문 — 흥미로운 케이스만

```swift
case let .view(.adjacentPhotoRequested(offset)):
    guard
        let currentID = state.selectedPhotoID,
        let currentIndex = state.photos.index(id: currentID)
    else { return .none }
    let targetIndex = currentIndex + offset
    guard state.photos.indices.contains(targetIndex) else { return .none }
    state.selectedPhotoID = state.photos[targetIndex].id
    return .none
```

VoiceOver 사용자는 좌우 스와이프로 페이지를 넘길 수 없다(스와이프가 이미 "다음 요소로 이동"에 쓰인다).
그래서 "이전/다음 사진" 액션을 만들고, 그 계산을 뷰가 아니라 리듀서에서 한다(뷰에 로직을 두지 않는다는 규칙).
끝에서는 `indices.contains`가 막아 준다.

```swift
case let .reactionSucceeded(request, photo):
    state.inFlightReactions.remove(request)
    // id 서브스크립트 대입은 없는 키를 새로 추가한다 — 사라진 사진을 되살리지 않도록 막는다.
    guard state.photos[id: photo.id] != nil else { return .none }
    state.photos[id: photo.id] = photo
    return .none
```

**이 `guard`가 없으면 생기는 일** — 리액션 요청을 보낸 뒤 목록을 다시 받았는데 그 사진이 삭제됐다고 하자.
뒤늦게 도착한 성공 응답이 `photos[id:] = photo`를 실행하면, `IdentifiedArray`는 **없는 키에 대입하면
맨 뒤에 추가**한다. 지워진 사진이 캐러셀 끝에 되살아난다. 코드 리뷰에서 잡힌 실제 버그였다.

```swift
case let .reactionFailed(request, error, appliedIsOn):
    state.inFlightReactions.remove(request)
    // 스냅샷을 통째로 되돌리면 그 사이 들어온 변화까지 덮어쓴다.
    if let photo = state.photos[id: request.photoID] {
        state.photos[id: request.photoID] = photo.settingReaction(
            request.kind, by: state.currentUserID, isOn: !appliedIsOn
        )
    }
    state.alert = Self.errorAlert(title: "리액션을 남기지 못했어요", error: error, canRetry: false)
    return .none
```

되돌리기는 **지금 상태에서 그 값만 반대로** 적용한다. `settingReaction`이 멱등이라 가능한 방식이다.

### 5-5. Effects — 정책이 셋 다 다르다

```swift
private enum CancelID: Hashable {
    case load
    case save
    case reaction(ReactionRequest)   // 요청마다 다른 키
}
```

| 이펙트 | 중복 차단 | 취소 정책 |
| :-- | :-- | :-- |
| `loadPhotos` | `isLoading` 가드 | 화면이 사라질 때만 |
| `setReaction` | `inFlightReactions` 잠금 | **취소하지 않는다** |
| `savePhoto` | `isSaving` 가드 | 화면이 사라질 때만 |

```swift
private func setReaction(_ state: inout State, kind: ReactionKind) -> Effect<Action> {
    guard let photo = state.selectedPhoto else { return .none }

    let request = ReactionRequest(photoID: photo.id, kind: kind)
    guard !state.inFlightReactions.contains(request) else { return .none }   // ①

    let isOn = !photo.hasReaction(kind, by: state.currentUserID)              // ②
    state.inFlightReactions.insert(request)                                   // ③
    state.photos[id: photo.id] = photo.settingReaction(kind, by: state.currentUserID, isOn: isOn)  // ④

    return .run { [setPhotoReactionUseCase] send in                           // ⑤
        do {
            let updated = try await setPhotoReactionUseCase.run(request.photoID, request.kind, isOn)
            await send(.reactionSucceeded(request, updated))
        } catch {
            guard let failure = Self.failure(error) else { return }
            await send(.reactionFailed(request, failure, appliedIsOn: isOn))
        }
    }
    .cancellable(id: CancelID.reaction(request))                              // ⑥
}
```

① 같은 자리가 이미 떠 있으면 무시 → ② 지금 눌려 있지 않으면 켜는 것 → ③ 잠금 → ④ 화면 먼저 갱신 →
⑤ 서버 요청 → ⑥ 요청별 취소 키

**⑤의 `[setPhotoReactionUseCase]`** — `.run` 클로저는 다른 태스크에서 실행되므로 `self`를 붙잡으면
Swift 6 동시성 검사에 걸린다. 필요한 의존성 값만 캡처한다.

> ### ⚠️ 이 파일에서 가장 중요한 부분
>
> 리액션에 `cancelInFlight: true`를 **쓰면 안 된다.**
>
> 처음에는 "연타하면 마지막 요청만 남기자"고 `.cancellable(id: .reaction, cancelInFlight: true)`를 썼다.
> 그런데 TCA는 취소된 태스크에서 보내는 Action을 **버린다.**
>
> ```swift
> // ComposableArchitecture/Effect.swift
> public func callAsFunction(_ action: Action) {
>     guard !Task.isCancelled else { return }
>     self.send(action)
> }
> ```
>
> 그래서 취소된 요청의 `reactionFailed`가 **영원히 도착하지 않고**, 화면에는 낙관적으로 그린 리액션만
> 남는다. 서버에는 없는데 화면에는 있는 상태로 굳는다. 다른 사진으로 넘어가며 리액션을 남겨도 같은 일이
> 벌어졌다.
>
> 그래서 **취소 대신 무시**로 바꾸고(`inFlightReactions`), 요청마다 취소 키를 나눠 서로 간섭하지 않게 했다.
> 이 정책은 테스트 `PhotoDetailReactionTests`의 "응답을 기다리는 동안 같은 자리를 다시 눌러도",
> "다른 사진으로 넘어가 리액션을 남겨도 앞선 요청은 끊기지 않는다" 두 개가 지키고 있다.

**오류 정규화는 한 곳에**

```swift
/// 취소(화면 이탈)면 `nil` — 알릴 사람이 이미 없다. 나머지는 `PhotoError`로 맞춘다.
private static func failure(_ error: any Error) -> PhotoError? {
    if error is CancellationError { return nil }
    return error as? PhotoError ?? .unknown
}
```

세 이펙트가 같은 `catch` 세 갈래를 반복하고 있었는데 이 함수로 모았다. `nil`이면 아무 Action도 보내지 않는다.

### 5-6. 얼럿

```swift
/// - Parameter canRetry: 다시 시도할 방법이 이 얼럿뿐인 실패(목록 조회)에만 켠다.
///   리액션·저장은 화면에 버튼이 그대로 남아 있어 다시 누르면 된다.
private static func errorAlert(title: String, error: PhotoError, canRetry: Bool) -> AlertState<Action.Alert> {
    AlertState {
        TextState(title)
    } actions: {
        if canRetry {
            ButtonState(action: .retryButtonTapped) { TextState("다시 시도") }
        }
        if error == .permissionDenied {
            ButtonState(action: .openSettingsButtonTapped) { TextState("설정으로 이동") }
        }
        ButtonState(role: .cancel) { TextState("확인") }
    } message: {
        TextState(error.userMessage)
    }
}
```

**"다시 시도"를 목록 조회에만 붙인 이유** — 조회가 실패하면 화면이 빈 카드로 굳고 `onAppear`는 다시 불리지
않는다. 사용자에게 재시도 수단이 없다. 반면 리액션·저장은 버튼이 화면에 그대로 있으니 다시 누르면 된다.

**"설정으로 이동"** — 권한을 한 번 거부하면 앱은 다시 물어볼 수 없다(iOS 정책). 설정 앱으로 보내는 게
유일한 길이라 그 경우에만 버튼을 붙인다.

```swift
case .alert(.presented(.openSettingsButtonTapped)):
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return .none }
    return .run { [openURL] _ in await openURL(settingsURL) }
```

문자열 `"app-settings:"`를 직접 쓰면 iOS가 스킴을 바꿨을 때 **조용히 아무 일도 안 하게** 된다.
컴파일러도 테스트도 못 잡으므로 Apple이 주는 상수를 쓴다.

---

## 6. PhotoDetailFeature — 뷰

### 6-1. Sources/PhotoDetailView.swift (205줄)

```swift
@ViewAction(for: PhotoDetailFeature.self)
public struct PhotoDetailView: View {
    @Bindable public var store: StoreOf<PhotoDetailFeature>

    public var body: some View {
        ZStack {
            CHALLAColor.Background.surface.ignoresSafeArea()
            glow.ignoresSafeArea()
            content
        }
        // 탑 내비게이션을 직접 그리므로 시스템 바는 숨긴다.
        .toolbar(.hidden, for: .navigationBar)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear { send(.onAppear) }
    }
```

- **`@ViewAction`** — `send(.onAppear)`처럼 쓰게 해 주는 매크로다. 없으면 `store.send(.view(.onAppear))`로
  매번 감싸야 한다
- **배경만 `ignoresSafeArea`** — 배경색과 글로우는 화면 끝까지 깔되, 내용은 safe area 안에 둔다.
  이렇게 하면 노치·다이나믹 아일랜드 높이를 코드가 알 필요가 없다
- **`.alert($store.scope(...))`** — State의 `alert`이 nil이 아니면 SwiftUI 얼럿이 뜬다. 닫히면 TCA가 알아서 nil로 만든다

**레이아웃**

```swift
VStack(spacing: 0) {
    CHALLATopNavigation.sub(title:leading:trailing:)
    photoArea
        .padding(.top, Metric.photoTopPadding)        // 32
        .padding(.horizontal, Metric.photoHorizontalPadding)  // 16
        // 사진과 Spacer가 둘 다 유연해서, 작은 화면에서 사진이 먼저 줄지 않도록 우선권을 준다.
        .layoutPriority(1)
    Spacer(minLength: Metric.reactionBarTopSpacing)   // 35
    reactionBar
    messageField
        .padding(.top, Metric.messageFieldTopSpacing) // 16
        .padding(.horizontal, Metric.messageFieldHorizontalPadding) // 20
}
```

수치는 전부 파일 하단 `private enum Metric`에 있고, 시안 좌표에서 어떻게 나온 값인지 주석으로 남겼다
(예: `photoTopPadding = 32`는 시안의 `146 − 114`).

**`layoutPriority(1)`이 필요한 이유** — 사진 영역은 비율(3:4)만 정해져 있고 `Spacer`도 유연하다.
공간이 모자라면 SwiftUI가 어느 쪽을 줄일지 모호하다. 우선권을 주면 사진이 먼저 줄지 않는다.

**캐러셀**

```swift
private var pager: some View {
    // TabView는 제안된 공간을 다 채우므로, 비율만 잡은 빈 뷰가 크기를 정해준다.
    Color.clear
        .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
        .overlay {
            TabView(selection: selection) {
                ForEach(store.photos) { photo in
                    PhotoCard(photo: photo).tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // 페이지 TabView는 VoiceOver에 사진을 넘길 방법을 주지 않는다.
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: Text("다음 사진")) { send(.adjacentPhotoRequested(offset: 1)) }
            .accessibilityAction(named: Text("이전 사진")) { send(.adjacentPhotoRequested(offset: -1)) }
        }
}
```

`TabView`는 크기를 스스로 정하지 않고 부모가 주는 공간을 다 쓴다. 그래서 비율만 가진 `Color.clear`가
크기를 잡고 그 위에 얹었다. `indexDisplayMode: .never`로 기본 점 표시를 끄고 우리 것을 쓴다.

**선택 바인딩**

```swift
/// TabView가 요구하는 양방향 바인딩. 읽기는 상태에서, 쓰기는 액션으로 보낸다.
private var selection: Binding<Photo.ID?> {
    Binding(
        get: { store.selectedPhotoID },
        set: { send(.photoSelected($0)) }
    )
}
```

`TabView`는 `Binding`을 요구하는데 TCA에서는 State를 직접 쓸 수 없다. 읽기는 State에서, 쓰기는 Action으로
보내는 다리를 놓는다. 이렇게 하면 스와이프도 결국 리듀서를 거치므로 테스트할 수 있다.

**채팅 입력창**

```swift
/// 채팅 입력창 자리. `.disabled(true)`는 글자색까지 비활성 색으로 바꿔 시안과 달라지므로 탭만 막고,
/// VoiceOver에는 반응 없는 입력창이 잡히지 않게 숨긴다.
private var messageField: some View {
    CHALLATextField(text: .constant(""), placeholder: "이 사진에 메시지를 보내 보세요.", textAlignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
}
```

`.disabled(true)`를 쓰면 디자인 시스템이 placeholder를 비활성 색(#444549)으로 그려 시안(#74767B)과 달라진다.
그래서 탭만 막았는데, 그러면 **VoiceOver 포커스는 여전히 잡힌다** — "편집 가능한 텍스트 필드"라고 읽어 주고
아무 일도 안 일어나는 자리가 된다. 그래서 접근성에서도 숨겼다. 코드 리뷰에서 지적된 부분이다.

### 6-2. Sources/Components/PhotoCard.swift (84줄)

**왜 별도 파일인가** — 캐러셀의 한 장을 그리는 일은 그 자체로 덩어리가 크다(이미지 로딩·스크림·헤더·스티커).
뷰에 다 넣으면 `PhotoDetailView`가 300줄이 된다.

```swift
Color.clear
    .aspectRatio(Self.aspectRatio, contentMode: .fit)
    .overlay { image }
    .overlay { scrim }
    .overlay { stickers }
    .overlay(alignment: .top) { PhotoAuthorHeader(...).padding(.top, Metric.headerTopPadding) }
    .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.xxlarge))
    .overlay { RoundedRectangle(...).strokeBorder(CHALLAColor.Line.normal, lineWidth: Metric.borderWidth) }
    .accessibilityLabel(Text("\(photo.author.nickname)님이 \(PhotoAuthorHeader.formatted(photo.capturedAt))에 찍은 사진"))
```

**겹치는 순서가 곧 그리는 순서다** — 사진 → 어두운 막 → 스티커 → 촬영자 → (모서리 자르기) → 테두리.

**`Color.clear`로 크기를 잡는 이유** — `scaledToFill`한 사진은 카드보다 크다. 사진이 크기를 정하게 두면
카드가 사진을 따라 커진다. 크기 없는 투명 뷰가 기준을 잡고 사진을 overlay로 얹으면, 넘친 부분은
`clipShape`가 잘라 낸다. #40의 `CHALLAFilmCard`가 쓰는 방식과 같다.

```swift
/// 캐시가 없어 다시 그릴 때마다 다시 받는다 — `CHALLAImageKit`(#25)이 생기면 이 자리를 바꾼다.
private var image: some View {
    AsyncImage(url: photo.imageURL) { phase in
        if let image = phase.image {
            image.resizable().scaledToFill()
        } else {
            // 실패와 로딩을 같은 모습으로 둔다 — 시안에 실패 표현이 없다.
            CHALLAColor.Background.level2
        }
    }
}
```

**왜 `AsyncImage`인가** — 이미지 로딩 모듈(#25)이 아직 없다. 임시로 표준 API를 쓰되, **교체 지점을 한 곳으로
모아 뒀다.** #25가 머지되면 이 프로퍼티만 바꾸면 되고 나머지 코드는 손대지 않는다.

```swift
/// 스티커 자리는 사진 크기에 대한 비율이라 실제 크기를 알아야 놓을 수 있다.
private var stickers: some View {
    GeometryReader { proxy in
        ForEach(photo.stickerPlacements, id: \.reaction.id) { reaction, placement in
            ReactionSticker(kind: reaction.kind, size: Metric.stickerSize)
                .rotationEffect(.degrees(placement.angleDegrees))
                .position(x: proxy.size.width * placement.xRatio,
                          y: proxy.size.height * placement.yRatio)
        }
    }
}
```

`GeometryReader`가 실제 픽셀 크기를 알려주면 비율을 곱해 위치를 만든다. 도메인이 비율로 저장한 값이
여기서 픽셀이 된다.

**VoiceOver 라벨** — 사진에는 대체텍스트가 없다(서버가 주지 않는다). 촬영자와 시각으로 한 문장을 합성했다.
없으면 VoiceOver 사용자는 화면의 주인공인 사진을 아예 인식하지 못한다.

### 6-3. Sources/Components/PhotoAuthorHeader.swift (63줄)

아바타 22 + 닉네임 + 날짜. 아바타는 #40이 만든 `CHALLAAvatar`를 그대로 쓴다
(그 컴포넌트 주석에 "상세·채팅 22"라고 이 화면이 이미 적혀 있었다 — 재사용을 전제로 만들어진 것이다).

```swift
AsyncImage(url: author.avatarURL) { image in
    CHALLAAvatar(photo: image, size: Metric.avatarSize)
} placeholder: {
    CHALLAAvatar(photo: nil, size: Metric.avatarSize)
}
```

디자인 시스템 컴포넌트는 **로드가 끝난 `Image`만 받는다**(DS는 네트워크를 모른다). URL을 실제로 받아오는 건
호출부인 Feature의 몫이라 여기서 `AsyncImage`로 감싼다.

```swift
/// 시안 간격 6에서 두 글자 상자의 여백(2 + 1.5)을 뺀 값.
static let rowSpacing: CGFloat = 6
    - CHALLATypography.body.medium.medium.lineBoxInset
    - CHALLATypography.body.small.medium.lineBoxInset
```

**왜 빼는가** — `challaFont`는 Figma 줄 높이를 재현하려고 글자 상자 위아래에 여백을 넣는다.
시안의 간격 6을 그대로 쓰면 그 여백만큼 더 벌어져 보인다. 디자인 시스템이 `lineBoxInset`으로 그 값을
알려주므로 빼 준다.

```swift
/// 사진 카드의 VoiceOver 문장도 같은 표기를 쓴다.
static func formatted(_ date: Date) -> String
```

날짜 포맷(`yyyy. M.d. HH:mm` → "2026. 7.16. 14:34")을 `static`으로 연 이유는 `PhotoCard`의 접근성 문장이
같은 표기를 써야 하기 때문이다. `DateFormatter`는 생성 비용이 커서 `static let`으로 한 번만 만든다.

### 6-3.5. Sources/StickerLayout.swift · StickerPlacement.swift (98줄)

**왜 필요한가** — 스티커를 사진 어디에 붙일지 정해야 한다. 서버가 좌표를 주지 않으니 클라이언트가 정한다.

```swift
public struct StickerPlacement: Sendable, Hashable {
    public let xRatio: Double        // 0~1
    public let yRatio: Double        // 0~1
    public let angleDegrees: Double
}
```

**왜 픽셀이 아니라 비율인가** — 사진 카드 크기는 기기마다 다르다. 비율로 두면 뷰가 `실제폭 × xRatio`로
곱하기만 하면 되고, 값 자체는 어디서든 유효하다.

**요구사항이 셋인데 서로 충돌한다.**

1. 무작위로 흩뿌려야 한다
2. 같은 리액션은 **늘 같은 자리**에 있어야 한다 — 아니면 화면을 다시 그릴 때마다 스티커가 춤춘다
3. 스티커끼리 **겹치면 안 된다**

2번 때문에 난수를 못 쓴다. 후보를 하나씩 떨어뜨렸다.

| 후보 | 결과 |
| :-- | :-- |
| `Double.random(in:)` | 호출할 때마다 다른 값 → 탈락 |
| Swift `hashValue` | **실행할 때마다 시드가 바뀐다.** 앱을 껐다 켜면 자리가 달라짐 → 탈락 |
| FNV-1a 해시 | 입력이 같으면 언제 어디서나 같은 값 → 채택 |

3번은 해시만으로는 풀리지 않는다. 해시는 값을 흩뿌릴 뿐 "옆에 뭐가 있는지" 모르기 때문이다.
그래서 **사진을 슬롯으로 나누고, 한 슬롯에 하나씩만 넣는다.**

```swift
/// 해시가 고른 시작 슬롯. 그 자리가 이미 찼으면 호출부가 다음 슬롯으로 민다.
static func preferredSlot(seed: String) -> Int {
    Int(fnv1a(seed) % UInt64(slotCount))
}

/// 슬롯 하나 안에서의 자리. 슬롯끼리 떨어져 있으므로 스티커도 겹치지 않는다.
static func placement(inSlot slot: Int, seed: String) -> StickerPlacement {
    let hash = fnv1a(seed)
    let column = slot % Grid.columns
    let row = (slot / Grid.columns) % Grid.rows

    return StickerPlacement(
        xRatio: Grid.columnCenter(column) + jitter(hash, shift: 0, spread: Grid.jitterX),
        yRatio: Grid.rowCenter(row) + jitter(hash, shift: 16, spread: Grid.jitterY),
        angleDegrees: Angle.lower + (Angle.upper - Angle.lower) * unit(hash, shift: 32)
    )
}
```

배정은 사진이 한다 (`StickerLayout.placements(for:)`).

```swift
var taken = Set<Int>()

return reactions.map { reaction in
    let seed = "\(id)|\(reaction.id)"
    var slot = preferredSlot(seed: seed)

    // 찜한 자리가 이미 찼으면 빈 자리를 만날 때까지 옆으로 민다.
    for _ in 0 ..< Grid.slotCount where taken.contains(slot) {
        slot = (slot + 1) % Grid.slotCount
    }
    taken.insert(slot)

    return (reaction, placement(inSlot: slot, seed: seed))
}
```

격자 수치는 시안 실측에서 나온다.

```swift
private enum Grid {
    static let columns = 3
    static let rows = 3
    static let jitterX = 0.035
    static let jitterY = 0.02

    /// 스티커가 놓이는 세로 구간. 위쪽 22%는 촬영자 표시 자리로 비워 둔다.
    private static let top = 0.22
    private static let bottom = 0.88
}
```

- **슬롯 간격 vs 스티커 크기** — 사진 358 × 477, 스티커 한 변 82. 슬롯 중심 간격은 가로 119 · 세로 105이고,
  흔들림(±12.5 · ±9.5)을 빼도 94 · 86이 남는다. 82보다 크므로 이웃과 절대 겹치지 않는다
- **위쪽 22%를 비우는 이유** — 거기 촬영자 표시(아바타 + 닉네임 + 시각)가 얹힌다. 처음엔 격자가 사진 전체를
  덮어서 💀 스티커가 날짜를 가렸다
- **`jitter`** — 슬롯 정중앙에만 놓으면 격자가 눈에 보인다. 겹치지 않는 선에서 조금씩 흔든다

```swift
/// 마지막 xor-fold는 FNV-1a의 하위 비트 확산이 약한 것을 보정한다 —
/// 앞부분이 같은 문자열끼리 하위 비트가 닮아서, 그대로 쓰면 값이 한쪽으로 몰린다.
private func fnv1a(_ string: String) -> UInt64 {
    let hash = string.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return hash ^ (hash >> 32)
}
```

- `&*`는 넘침을 허용하는 곱셈이다 (그냥 `*`면 오버플로로 크래시한다)
- **xor-fold가 왜 필요한가** — FNV-1a는 하위 비트가 잘 안 섞인다. `photo-1|user-me|clap`과
  `photo-1|user-me|skull`처럼 앞부분이 같으면 하위 16비트가 닮아 좌표가 몰린다. 상위 비트를 접어 내려 보정한다

**함정** — 이 규칙을 바꾸면 **기존 스티커 위치가 전부 달라진다.** 서버가 좌표를 주기 시작하면 이 계산 대신
서버 값을 쓰면 된다.

### 6-4. Sources/Components/PhotoPageIndicator.swift (59줄)

```swift
/// 현재 장을 가운데 두는 창. 양 끝에서는 창이 밀려 가장자리에 붙는다.
var visibleIndices: Range<Int> {
    guard count > Metric.maxVisible else { return 0 ..< max(count, 0) }
    let half = Metric.maxVisible / 2
    let start = min(max(currentIndex - half, 0), count - Metric.maxVisible)
    return start ..< (start + Metric.maxVisible)
}

/// 시안 실측 — 현재 점에서 두 칸까지는 10, 세 칸은 8, 그 밖은 6.
private func diameter(at index: Int) -> CGFloat
```

**왜 창(window)이 필요한가** — 처음엔 사진 수만큼 점을 그렸다. 사진이 20장이면 `20 × 18 = 360pt`로
화면 폭을 넘긴다. 방에 사진이 쌓이면 바로 깨지는 코드였고 리뷰에서 잡혔다.

크기 규칙(10/8/6)은 시안 그대로다. 5장짜리 시안 두 개(첫 장 선택 / 마지막 장 선택)를 이 규칙에 넣으면
정확히 시안과 같은 그림이 나온다.

### 6-5. Sources/Components/ReactionBar.swift (42줄)

```swift
/// 내가 이미 남긴 종류. 시안에 눌린 칩의 모습이 없어 VoiceOver 표시에만 쓴다.
let selectedKinds: Set<ReactionKind>
let onTap: (ReactionKind) -> Void
```

```swift
ForEach(ReactionKind.allCases, id: \.self) { kind in
    Button { onTap(kind) } label: { chip(kind) }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.accessibilityLabel) 리액션")
        .accessibilityAddTraits(selectedKinds.contains(kind) ? [.isSelected] : [])
}
```

**`onTap` 클로저로 받는 이유** — 이 컴포넌트는 Store를 모른다. 뷰 계층 아래로 Store를 내려보내지 않으면
나중에 다른 화면(예: 채팅)에서도 그대로 쓸 수 있고, 프리뷰도 쉽다.

**선택 상태를 색으로 표현하지 않은 이유** — 시안에 "눌린 칩"의 모습이 없다. 임의로 색·테두리를 만들면
디자이너 검수에서 되돌려야 한다. 대신 접근성 트레이트로만 표시했고, 눈으로 보는 피드백은 사진 위 스티커가 한다.

### 6-6. Sources/Components/ReactionSticker.swift (46줄)

**왜 필요한가** — 시안의 스티커는 이모지 실루엣을 따라 흰 테두리가 둘러져 있다. SwiftUI에 그런 API가 없다.

```swift
/// 테두리는 글리프 실루엣을 따라가야 하므로, 흰 실루엣을 여덟 방향으로 밀어 깐다.
/// 이모지는 색이 박힌 글리프라 `foregroundStyle`이 통하지 않아 채도를 없애고 밝기를 올린다.
private var outline: some View {
    ZStack {
        ForEach(0 ..< 8) { step in
            let radians = Double(step) * .pi / 4
            glyph
                .grayscale(1)
                .brightness(1)
                .offset(x: cos(radians) * Metric.outlineWidth, y: sin(radians) * Metric.outlineWidth)
        }
    }
}
```

두 가지 트릭이 들어 있다.

1. **흰 실루엣 만들기** — 이모지는 색이 박힌 비트맵이라 `foregroundStyle(.white)`가 통하지 않는다.
   `grayscale(1)`로 색을 빼고 `brightness(1)`로 밝기를 최대로 올리면 **알파만 남은 흰 모양**이 된다
2. **테두리 만들기** — 그 흰 실루엣을 45°씩 8방향으로 8pt 밀어 깔고, 그 위에 원본을 얹는다.
   실루엣이 사방으로 조금씩 삐져나와 테두리처럼 보인다

8pt는 시안 실측에서 나왔다 — 전체 82, 글리프 66.5이므로 양쪽 8씩이다.

**비용** — 스티커 하나에 `Text` 9개 + 필터다. 지금은 사진당 스티커가 몇 개뿐이라 괜찮지만, 많아지면
`drawingGroup()`을 재 보는 게 좋다(리뷰에서 제안받았고 측정 없이는 넣지 않았다).

### 6-7. Sources/Components/ReactionKind+Emoji.swift (27줄)

```swift
extension ReactionKind {
    /// 화면에 그리는 글리프. Figma는 Noto Color Emoji 벡터지만 시스템 이모지로 대신한다 —
    /// 검수에서 차이가 확인되면 그때 SVG 에셋으로 바꾼다.
    var emoji: String { ... }

    /// VoiceOver가 읽을 이름.
    var accessibilityLabel: String { ... }
}
```

**이 파일의 존재 이유가 곧 경계다** — 도메인은 "무슨 뜻인가"(`.clap`)를, 화면은 "어떻게 보이나"(`"👏"`)를 안다.
확장으로 두면 도메인 타입을 건드리지 않고 표시 규칙만 여기서 바꿀 수 있다.

에셋 5개를 들이지 않고 시스템 이모지를 쓴 건 절충이다. 기기·OS 버전에 따라 글리프가 조금 다르지만,
검수에서 문제가 되면 그때 SVG로 바꾸면 된다.

---

## 7. PhotoDetailFeatureDemo — 조립과 검증

`Projects/Photo/PhotoDetail/PhotoDetailFeatureDemo/`

**왜 데모앱이 필요한가.** 실앱(`CHALLAApp`)에는 이 화면으로 가는 길이 아직 없다 — 방 목록도, 방 상세도
만들어지지 않았다. 데모앱이 없으면 화면을 **한 번도 눈으로 못 보고** 리뷰를 올려야 한다.

여기에 저장소만의 사정이 하나 더 있다. 시뮬레이터를 탭으로 조작하는 도구가 없어서, 화면에 도달하려면
**실행 인자로 바로 띄울 수 있어야** 한다. `zeplin-ui-verification` 스킬이 이 규약을 쓴다.

### 7-1. Project.swift (22줄)

```swift
additionalInfoPlist: [
    // 다운로드 버튼이 사진첩 쓰기를 요청한다 — 이 값이 없으면 권한 요청 순간 앱이 죽는다.
    "NSPhotoLibraryAddUsageDescription": .string("찍은 사진을 앨범에 저장하기 위해 사용해요.")
],
dependencies: [.photoDetailFeature, .photoDomain, .photoLibrary, .designSystem, .composableArchitecture]
```

데모앱은 **규칙 2의 유일한 예외**다 — 앱 조립 지점이라 Data(여기서는 Mock)와 Core를 직접 알아도 된다.

### 7-2. Sources/PhotoDetailDemoApp.swift (17줄)

```swift
@main
struct PhotoDetailDemoApp: App {
    init() { CHALLAFontRegister.register() }
    var body: some Scene { WindowGroup { DemoRootView() } }
}
```

커스텀 폰트(SUIT·Dirtyline)는 앱 진입점에서 한 번 등록해야 한다. 안 하면 시스템 폰트로 그려져
시안 대조가 무의미해진다.

### 7-3. Sources/DemoLaunchArguments.swift (40줄)

```swift
struct DemoLaunchArguments: Equatable {
    enum Screen: String { case photoDetail = "photo-detail" }
    enum State: String, CaseIterable { case `default`, loading, empty, error }

    let screen: Screen?
    let state: State

    static func parse(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Self
}
```

```bash
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state empty
```

**왜 필요한가** — 위에서 말한 대로 화면·상태에 **탭 없이 도달**하기 위해서다. 로딩 상태나 에러 상태는
Mock을 갈아끼우지 않으면 재현조차 어려운데, 인자 하나로 띄울 수 있으면 스크린샷 4장을 자동으로 찍을 수 있다.

`parse`가 기본 인자로 `ProcessInfo.processInfo.arguments`를 받는 건 테스트를 위해서다 — 임의 배열을 넣어 검증할 수 있다.

### 7-4. Sources/DemoRootView.swift (72줄)

```swift
var body: some View {
    if let screen = arguments.screen {
        switch screen {
        case .photoDetail: PhotoDetailDemoScreen(demoState: arguments.state)
        }
    } else {
        statePicker    // 인자 없이 실행하면 상태 목록
    }
}
```

인자로 실행하면 그 화면이 바로, Xcode에서 그냥 실행하면 상태를 고르는 목록이 뜬다. 두 사용 방식을 다 지원한다.

```swift
private struct PhotoDetailDemoScreen: View {
    /// body가 다시 평가돼도 Store가 새로 만들어지지 않도록 @State로 들고 있는다.
    @State private var store: StoreOf<PhotoDetailFeature>

    init(demoState: DemoLaunchArguments.State) {
        _store = State(initialValue: Store(initialState: ...) {
            PhotoDetailFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerDependencies(for: demoState, into: &$0)
        })
    }
}
```

- **`@State`로 Store를 보관** — SwiftUI는 body를 여러 번 평가한다. Store를 body 안에서 만들면 매번 새로
  만들어져 상태가 초기화된다. #13에서 리뷰로 잡힌 사항이라 같은 실수를 반복하지 않았다
- **`_printChanges()`** — 콘솔에 Action과 State 변화를 찍어 준다. 디버깅용이라 데모에만 붙인다

### 7-5. Sources/CompositionRoot.swift (48줄)

```swift
static func registerDependencies(for demoState: DemoLaunchArguments.State, into values: inout DependencyValues) {
    let repository = DemoPhotoRepository(scenario: scenario(for: demoState))

    values.fetchRoomPhotosUseCase = .live(repository: repository)
    values.setPhotoReactionUseCase = .live(repository: repository)
    values.savePhotoUseCase = .live(repository: repository, photoLibrary: PhotoLibraryAdapter())
}
```

**여기가 "이름표에 실제 물건을 꽂는" 유일한 자리다.** Domain은 `liveValue`를 두지 않으므로 누군가는 이 일을
해야 하고, 그게 앱의 책임이다. 실앱에는 `CHALLAApp/Sources/CompositionRoot.swift`가 같은 역할을 한다.

**조회는 Mock, 저장은 진짜다.**

> 사진 조회는 Mock이지만 사진첩 저장은 실제 구현을 쓴다 — 시뮬레이터에서 끝까지 확인할 수 있는 동작이라
> 흉내 내면 검증이 되지 않는다.

서버가 없으니 조회는 흉내 낼 수밖에 없지만, 사진첩 저장은 시뮬레이터에서 진짜로 된다. 흉내 내면
권한 팝업이 뜨는지, 사진 앱에 실제로 들어가는지 확인할 방법이 없어진다.

```swift
/// Core의 사진첩 저장을 도메인 인터페이스에 잇는다.
/// Core는 도메인을 모르므로(`Keychain`과 같은 이유) 어댑터가 필요하고, `PhotoData`가 생기면 그쪽으로 옮긴다.
private struct PhotoLibraryAdapter: PhotoLibraryWriting {
    private let store = PhotoLibraryStore()

    func save(imageData: Data) async throws {
        do { try await store.save(imageData: imageData) }
        catch PhotoLibraryError.permissionDenied { throw PhotoError.permissionDenied }
        catch { throw PhotoError.saveFailed }
    }
}
```

**어댑터의 전부는 오류 번역이다.** Core는 `PhotoLibraryError`, Domain은 `PhotoError`를 쓴다.
이 6줄이 두 모듈이 서로를 모르게 해 준다.

### 7-6. Sources/DemoPhotoRepository.swift (82줄)

```swift
enum Scenario {
    case populated(DemoPhotoStore)   // 사진 5장
    case neverFinishes               // 로딩에서 멈춤
    case empty                       // 사진 0장
    case failure(PhotoError)         // 조회 실패
}
```

`--state` 인자가 이 네 가지로 번역된다. `neverFinishes`는 `Task.sleep(for: .seconds(60 * 60))` —
로딩 상태를 스크린샷으로 찍으려면 멈춰 있어야 한다.

```swift
/// 응답이 즉시 오면 로딩 표시를 볼 수 없어 일부러 늦춘다.
private let latency: Duration = .milliseconds(600)
```

```swift
/// 리액션 반영 결과를 들고 있는 메모리 저장소.
actor DemoPhotoStore {
    private var photos: [Photo]
    func all() -> [Photo]
    func setReaction(photoID:kind:isOn:userID:) -> Photo?
}
```

**왜 `actor`인가** — 리액션을 누르면 상태가 바뀌고 그 결과를 다음 조회에서도 보여야 한다.
여러 요청이 동시에 접근할 수 있는 가변 상태라 Swift 6에서는 격리가 필요하다. `actor`면 컴파일러가
데이터 경쟁을 막아 준다.

```swift
func imageData(for photo: Photo) async throws -> Data {
    do {
        let (data, _) = try await URLSession.shared.data(from: photo.imageURL)
        return data
    } catch { throw PhotoError.network }
}
```

여기만 진짜 네트워크를 쓴다 — 사진첩에 저장하려면 진짜 바이트가 필요하기 때문이다.

### 7-7. Sources/DemoFixture.swift (51줄)

시안에 적힌 값을 그대로 쓴다 — 방 이름 "해피하우스 강릉 여행", 닉네임 "나는야멋쟁이토마토",
시각 `2026. 7.16. 14:34`. **시안 대조를 하려면 화면의 글자가 시안과 같아야** 한다.

```swift
// 저장소에 샘플 이미지를 커밋하지 않고 실행 시점에 받아 쓴다 (검수앱 갤러리와 같은 방식).
guard let imageURL = URL(string: "https://picsum.photos/seed/challa-\(index)/600/800") else { return nil }
```

`seed`를 고정해 두면 같은 사진이 매번 나와 스크린샷 비교가 가능하다.
첫 장에만 남이 남긴 리액션 하나를 붙여, 실행하자마자 스티커 상태를 볼 수 있게 했다.

### 7-8. Resources/Assets.xcassets/

`AppIcon.appiconset/Contents.json`은 **내용이 비어 있어도 반드시 있어야 한다.**

앱 타깃에는 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`이 기본으로 박힌다. 그러면 `actool`(에셋 컴파일러)이
"AppIcon이라는 아이콘 세트를 찾아라"를 필수 작업으로 받고, 못 찾으면 **경고가 아니라 에러**를 낸다.

```
error: None of the input catalogs contained a matching stickers icon set, app icon set, or icon stack named "AppIcon".
```

scaffold 템플릿이 이 파일을 만들어 주지 않아 손으로 넣었다. `LoginFeatureDemo`도 같은 빈 파일을 갖고 있다.

---

## 8. 테스트 — 무엇을 막고 있나

테스트는 "잘 되는지" 확인용이 아니라 **정책을 문장으로 고정**해 두는 장치다. 이름만 훑어도 이 화면의
규칙을 알 수 있게 썼다.

### 8-1. PhotoDomain (18개)

| 테스트 | 이게 깨지면 |
| :-- | :-- |
| 켜면 붙는다 / 끄면 지워진다 | 리액션 기본 동작 |
| **같은 값을 두 번 적용해도 결과가 같다** | 멱등성이 깨져 롤백이 어긋난다 |
| 이미 없는 리액션을 꺼도 아무 일 없다 | 롤백이 예외를 만든다 |
| 남이 남긴 같은 종류는 건드리지 않는다 | 내 리액션을 지우다 남의 것까지 지운다 |
| 서버가 중복으로 줘도 하나만 남는다 | 스티커 겹침 · `ForEach` id 충돌 |
| 리액션 신원은 종류 + 사람 | id 규칙이 흔들리면 위 두 개가 동시에 깨진다 |
| **같은 사진이면 늘 같은 자리** | 스티커가 리렌더마다 움직인다 |
| **한 사진에 종류를 다 눌러도 겹치지 않는다** | 스티커 두 개가 포개진다 (사진 50장 × 조합 10개 검사) |
| 여러 사람이 같은 종류를 남겨도 겹치지 않는다 | 같은 이모지끼리 포개진다 |
| 스티커가 촬영자 표시를 가리지 않는다 | 닉네임·시각이 스티커에 덮인다 |
| 사진 밖으로 나가지 않는다 | 스티커가 잘려 나간다 |
| 취소는 그대로 던진다 | 화면 이탈 시 엉뚱한 실패 얼럿 |
| 계약 위반 오류의 정규화 | 화면이 모르는 오류를 받는다 |

### 8-2. PhotoDetailFeature (23개)

`PhotoDetailTestSupport.swift`가 세 파일의 공통 도구를 갖고 있다.

```swift
@MainActor
func makeTestStore(initialPhotoID:photos:setReaction:save:) -> TestStoreOf<PhotoDetailFeature>

/// 사진 목록을 이미 받아 첫 장을 펼친 상태에서 시작하는 Store.
@MainActor
func openedTestStore(photos:setReaction:save:) async -> TestStoreOf<PhotoDetailFeature>
```

대부분의 테스트가 "사진이 이미 있는 상태"에서 시작하므로, 그 준비를 `openedTestStore` 하나로 묶었다.

테스트가 읽는 법(예시):

```swift
await store.send(.view(.reactionTapped(.clap))) {
    $0.inFlightReactions = [Fixture.request(.clap, photoID: "photo-1")]
    $0.photos[id: "photo-1"] = target.settingReaction(.clap, by: Fixture.currentUserID, isOn: true)
}
await store.receive(\.reactionSucceeded) {
    $0.inFlightReactions = []
    $0.photos[id: "photo-1"] = confirmed
}
```

- `send` — Action을 넣고, 클로저에 **예상되는 State 변화**를 적는다. 하나라도 다르면 실패한다
- `receive` — Effect가 보낸 Action을 기다린다. 안 오면 실패하고, 예상 못 한 Action이 오면 그것도 실패한다

이 엄격함 덕분에 "리액션을 눌렀을 때 정확히 이것만 바뀐다"가 문서처럼 남는다.

특히 중요한 세 개:

| 테스트 | 막고 있는 것 |
| :-- | :-- |
| 응답을 기다리는 동안 같은 자리를 다시 눌러도 요청이 겹치지 않는다 | 중복 요청 |
| 다른 사진으로 넘어가 리액션을 남겨도 앞선 요청은 끊기지 않는다 | **`cancelInFlight` 회귀** — 이걸 되돌리면 이 테스트가 깨진다 |
| 응답이 늦게 왔는데 그 사진이 목록에서 사라졌으면 되살리지 않는다 | `IdentifiedArray` 대입 함정 |

비동기 순서를 만들 때는 `AsyncStream.makeStream`으로 응답을 붙잡아 두고, 호출 횟수는 `LockIsolated`로 센다.

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
let store = await openedTestStore(photos: [target], setReaction: { _, _, _ in
    await stream.first { _ in true }     // 여기서 멈춘다
    return confirmed
})
...
continuation.yield()                      // 이제 응답을 흘려보낸다
```

### 8-3. Tests/Support의 Mock

```swift
final class MockPhotoRepository: PhotoRepository {
    private let state = OSAllocatedUnfairLock(initialState: State())
    ...
}
```

**왜 락이 필요한가** — `PhotoRepository`는 `Sendable`이라 여러 스레드에서 안전해야 한다. Mock은 호출 인자를
기록하는 가변 상태를 가지므로, 그냥 두면 `Sendable`을 만족하지 못한다. `@unchecked Sendable`로 우기는 대신
락으로 감싸 **진짜로** 안전하게 만들었다. iOS 17 타깃이라 Swift 6의 `Mutex`(iOS 18+)는 못 쓴다.

---

## 9. 디자인 시스템·빌드 설정 변경분

### 9-1. CHALLADesignSystem

| 파일 | 변경 | 왜 |
| :-- | :-- | :-- |
| `Sources/Foundation/CHALLAIcon.swift` | `case downloadSimple` 추가 (23 → 24종) | 탑 내비 다운로드 버튼 |
| `Resources/Icons.xcassets/DownloadSimple.imageset/` | SVG + Contents.json 신규 | **Zeplin에서 asset export가 안 돼 직접 그렸다.** 다른 아이콘과 같은 획 두께(2.25)로 맞췄고, 원본을 받으면 교체한다 |
| `Sources/Foundation/CHALLAColor.swift` | `Material.floating`(검정 77%) | 리액션 칩·툴팁 배경. Feature에서 `Color(hex:)`를 직접 쓰는 건 규칙 위반이라 토큰으로 올렸다 |
| `Sources/Foundation/CHALLARadius.swift` | `xxlarge = 44.5` | 사진 카드 모서리. **스케일의 다음 단계인지 이 카드 전용인지는 디자이너 확인 필요** |
| `MODULE.md` | 아이콘 수·둥글기 목록 갱신, 직접 그린 아이콘 기록 | 공개 API가 바뀌면 같은 PR에서 문서를 고치는 게 규칙이다 |
| `CHALLADesignSystemApp/.../ColorGallery.swift` | Material 섹션에 Floating 행 | 새 토큰은 검수앱 갤러리에 나열해야 디자이너가 확인할 수 있다 (아이콘 갤러리는 `allCases`라 자동) |

**왜 Feature에서 색을 직접 쓰지 않나** — `.claude/rules/design-system.md`가 `Color(hex:)`·`Font.custom`
직접 호출을 금지한다. 토큰이 없으면 **토큰 추가를 먼저 제안**하는 게 규칙이라, 검정 77%도 44.5도
DS에 올린 뒤 가져다 썼다. 그래야 다음에 같은 값이 필요할 때 다시 만들지 않는다.

### 9-2. Tuist/ProjectDescriptionHelpers/Dependency/DependencyInfo.swift

```swift
static let photoDomain          // Projects/Photo/PhotoDomain
static let photoDetailFeature   // Projects/Photo/PhotoDetail/PhotoDetailFeature
static let photoLibrary         // Projects/Core/PhotoLibrary
```

각 `Project.swift`는 `.project(target:path:)`를 직접 쓰지 않고 여기 값을 참조한다.
경로가 한 곳에 모여 있어 모듈을 옮겨도 이 파일만 고치면 된다.

---

## 10. 용어 사전

| 용어 | 뜻 |
| :-- | :-- |
| **낙관적 갱신** | 서버 응답 전에 화면을 먼저 바꾸는 방식. 빠르게 느껴지지만 실패 시 되돌릴 책임이 생긴다 |
| **멱등(idempotent)** | 같은 요청을 여러 번 해도 결과가 같은 성질. 재시도·취소가 안전해진다 |
| **의존성 역전** | 상위(Domain)가 인터페이스를 정의하고 하위(Data)가 구현하는 구조. Domain이 서버를 모르게 된다 |
| **Effect** | TCA에서 바깥 세상과의 대화(네트워크·파일). 결과를 Action으로 되돌려 보낸다 |
| **CancelID** | Effect를 나중에 취소하기 위한 이름표 |
| **@Presents** | 얼럿·시트처럼 "떴다 사라지는" 상태를 TCA가 관리하게 하는 표시 |
| **IdentifiedArray** | 순서와 id 접근을 둘 다 지원하는 배열 |
| **safe area** | 노치·홈 인디케이터를 피한 안전 영역 |
| **FNV-1a** | 문자열을 숫자로 바꾸는 간단한 해시. 값이 고정이라 결정적 난수의 시드로 쓴다 |

---

## 11. 실행과 검증

```bash
# 1. 워크스페이스 생성 (Xcode 프로젝트는 커밋되지 않으므로 매번 필요)
mise exec -- tuist install
mise exec -- tuist generate

# 2. 테스트 (시뮬레이터에서 1초 안에 끝난다)
mise exec -- tuist test PhotoDomain PhotoDetailFeature

# 3. 데모앱 빌드 — 기기 이름은 맥마다 다르므로 먼저 확인한다
xcrun simctl list devices available
xcodebuild -workspace CHALLA.xcworkspace -scheme PhotoDetailFeatureDemo \
  -destination 'name=<위 목록의 기기>' build

# 4. 상태별로 띄워 보기
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state default
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state loading
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state empty
xcrun simctl launch booted com.challa.photodetailfeature.demo --screen photo-detail --state error

# 5. 스크린샷
xcrun simctl io booted screenshot ~/Desktop/photo-detail.png
```

`Configs/Shared.xcconfig`가 없으면 1번이 실패한다(매니페스트가 API 값을 읽는다).
`Configs/Shared.xcconfig.template`을 복사해 값을 채우면 된다.

---

## 12. 남은 일

| 항목 | 내용 |
| :-- | :-- |
| `PhotoData` 모듈 | 서버 명세 확정 후. `DemoPhotoRepository`가 하던 일을 진짜로 구현하고, `PhotoLibraryAdapter`도 이쪽으로 옮긴다 |
| 채팅 | 입력창은 모양만 있다. 키보드·말풍선·전송이 후속 이슈 |
| `CHALLAApp` 배선 | 이 화면을 push할 `RoomDetailFeature`가 아직 없다 |
| `CHALLAImageKit`(#25) | `PhotoCard.image`의 `AsyncImage`를 교체한다 |
| **사진첩 저장 실측** | 리듀서는 테스트로 덮었지만, 권한 팝업 → 사진 앱 저장까지는 직접 눌러 봐야 한다 |
| 디자이너 확인 | `CHALLARadius.xxlarge = 44.5`의 성격, 직접 그린 `DownloadSimple` 아이콘, 시스템 이모지 글리프 |
