# RoomDetailFeature

## 레이어와 책임

**Feature 레이어**. 방 상세 화면 — 제목·슬롯 그리드, 참여자 아바타와 초대 코드 팝오버,
인화 카운트다운을 그린다 (이슈 #57, 시안 4장 기준).

`RoomDomain`·`PhotoDomain`의 UseCase만 주입받고(규칙 2), 화면 전환(뒤로가기·촬영·채팅)은
전부 `delegate`로 App에 알린다(규칙 3).

두 도메인을 함께 쓰는 이유: 방 상세 API(`GET /rooms/{id}`)는 사진 URL을 주지 않고
대표 이미지 한 장만 준다. 그리드를 채울 사진은 `GET /photos`가 유일한 출처라
`PhotoDomain`의 조회를 쓴다 (`docs/ARCHITECTURE.md`의 "결과 목록은 RoomDetailFeature로 흡수").

## 화면이 갈리는 기준

기준이 둘로 나뉜다 — 하나만 보고 판단하면 어긋난다.

| 영역 | 기준 | 규칙 |
| :-- | :-- | :-- |
| 슬롯 그리드 | **사진 개수** | 찍힌 자리는 사진, 남은 자리는 빈 칸. 사진은 인화 완료면 선명하게, 그 전이면 블러 |
| 하단 동작 | **방 상태** | 촬영 중은 사진 찍기, 인화 대기는 카운트다운, 인화 완료는 없음 |

촬영 중에 찍은 사진도 블러로 보인다(기획 확인) — 그래서 그리드는 상태가 아니라 사진 유무로 갈린다.

## 공개 API

### RoomDetailFeature (리듀서)

- `State(room:)` — 홈에서 받은 `Room`을 품고 시작한다. 첫 프레임부터 제목·슬롯 그리드가 그려지고,
  초대 코드·참여자·사진은 진입 후 조회로 채운다
  - `room` · `detail`(초대 코드+참여자) · `photos` · `detailLoad` · `isInvitePopoverPresented` · `toast`
- `Action.delegate` — `closeTapped` · `shootTapped` · `chatTapped`
- 진입 시 상세와 사진을 병렬 조회한다. 방 상태로 거르지 않는다 — 촬영 중에도 찍은 사진이 필요하고,
  거르면 홈에서 받은 상태가 낡은 경우를 따라잡는 분기가 더 생긴다
- 조회 실패는 얼럿 없이 화면을 비워 둔다. 참여자 바가 뜨지 않고 슬롯은 빈 칸이 되며,
  팝오버를 여는 순간 상세를 다시 조회한다(복구 지점)

### RoomDetailView

- `RoomDetailView(store:)` — `@ViewAction`으로 뷰 액션을 보낸다
- 카운트다운은 State에 두지 않는다. `TimelineView`가 `photoPrintCompletedAt`에서 매초 계산한다 —
  초마다 상태를 바꾸면 화면 전체가 다시 그려지고 테스트에 타이머가 섞인다

### CopyToPasteboard

- 초대 코드 복사용 의존성. `UIPasteboard` 싱글턴 직접 접근을 막으려고 감쌌다(규칙: `@Dependency`로 주입)
- `liveValue`만 채워져 있다 — Data 접근이 없는 OS 호출 한 줄이라 합성 루트 조립이 필요 없다.
  `testValue`는 미구현이라 테스트가 갈아끼우지 않고 호출하면 실패로 드러난다

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `PhotoDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `CHALLAApp`(조립 예정) · `RoomDetailFeatureDemo`(데모)

## 알려진 미구현

- **툴팁** — 시안(5604:19130)의 "초대 코드로 친구를 초대해보세요"가 빠져 있다.
  디자인 시스템에 Tooltip 컴포넌트가 없어 담당자 확인 후 추가한다
- **슬롯 탭 → 사진 상세** — `Delegate`에 `photoTapped`를 추가하고 App이 `PhotoDetailFeature`를 연다.
  실서버 구현(`PhotoData`)이 없어 지금 연결하면 빈 화면이라 미룬다
- **카운트다운이 0에 도달한 뒤** — 서버가 상태를 바꿔줄 때까지 `0:00:00`으로 멈춘다. 기획 확인 필요

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomDetailFeature
```

TCA `TestStore`로 리듀서를 검증한다 — 진입 조회(상세+사진), 실패 정책, 팝오버 재조회,
클립보드 복사와 토스트 타이머(`TestClock`), delegate 위임, 카운트다운 표기 규칙.

화면 확인은 데모앱으로 한다. 상태별로 실행 인자를 받는다:

```bash
xcrun simctl launch booted com.challa.roomdetailfeature.demo \
  --screen detail --state <shooting|shootingPartial|printWaiting|printed|invite|error>
```
