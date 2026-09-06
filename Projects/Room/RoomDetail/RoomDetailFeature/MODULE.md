# RoomDetailFeature

## 레이어와 책임

**Feature 레이어**. 방 상세 화면 — 제목·슬롯 그리드, 참여자 아바타와 초대 코드 팝오버,
인화 카운트다운을 그린다 (이슈 #57, 시안 4장 기준).

`RoomDomain`·`PhotoDomain`의 UseCase만 주입받고(규칙 2), 화면 전환(뒤로가기·촬영·채팅)은
전부 `delegate`로 App에 알린다(규칙 3).

방 설정 화면(이름 수정 드로어 포함)도 이 모듈이 갖는다 — 상세에서만 들어가는 화면이라
별도 Feature로 쪼개지 않았다 (#82).

**사진 찍기는 준비까지 마치고 넘긴다.** 카메라 화면은 아무것도 스스로 조회하지 않아서,
버튼을 누르면 `ShootEntry`의 `ShootPreparation`이 촬영 가능 방 목록·필터(LUT 포함)·카메라/사진첩 권한을
갖추고, 전부 성공했을 때만 `delegate(.cameraRequested)`를 보낸다. 준비 중에는 버튼이 로딩으로 바뀌고
다시 눌리지 않으며, 실패하면 얼럿(권한이면 설정 앱으로, 조회 실패면 그 문구)을 띄우고 넘어가지 않는다.
홈의 촬영 뱃지와 같은 준비를 같은 코드로 한다 — 규칙은 `ShootEntry/MODULE.md`.

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
  - `room` · `detail`(초대 코드+참여자) · `photos` · `detailLoad` · `isInvitePopoverPresented` · `toast` · `alert`
    · `didShowPrintWaitingToast`(인화 대기 안내를 이 화면에서 띄웠는지)
- `Action.delegate` — `closeTapped` · `settingsTapped`(설정 화면 요청 — App이 조립) ·
  `cameraRequested(CameraEntry)`(촬영 준비 완료) · `chatTapped` ·
  `photoTapped(Photo.ID)`(사진 슬롯 탭 → 사진 상세)
- `isPreparingShoot` — 촬영 준비 중. 사진 찍기 버튼이 로딩으로 바뀐다
- `downloadAll` — 전체 다운로드 상태(`idle` / `running(completed:total:)`).
  인화 완료 방의 하단 버튼이 이 값을 그린다: 받는 중에는 `12/24 저장 중`, 끝나면 원래 문구로 돌아간다.
  버튼을 잠그지 않는다 — 앱은 사진첩에서 지워졌는지 알 수 없어 잠그면 다시 받을 길이 막힌다.
  사진첩 권한 거부는 설정으로 보내는 얼럿으로 알린다
- 저장 중에 뒤로가기를 누르면 바로 닫지 않고 **확인 드로어로 멈출지 먼저 묻는다** — 중간까지 받은 사진은
  사진첩에 남고, 다시 받으면 그 장들이 중복되기 때문이다.
  되돌리기 어려운 동작은 드로어(`CHALLADrawer`), 얼럿은 조회·저장 실패 안내 전용이다
- `toast` — 안내 문구와 뜨는 자리(`top`/`bottom`)를 함께 들고 다닌다.
  초대 코드 복사는 상단(시안), 전체 다운로드 완료는 방금 누른 버튼 가까이인 하단에 뜬다
- 인화 대기 방에 들어오면 상단에 안내 토스트를 한 번 띄운다. 진입과 상세 응답 두 곳에서 확인하므로
  홈에서 받은 상태가 낡아도 따라잡고, `didShowPrintWaitingToast`로 인화 완료 알람의 재조회 때 다시 뜨는 것을 막는다
- 진입 시 상세와 사진을 병렬 조회한다. 방 상태로 거르지 않는다 — 촬영 중에도 찍은 사진이 필요하고,
  거르면 홈에서 받은 상태가 낡은 경우를 따라잡는 분기가 더 생긴다
- 상세 조회가 실패하면 홈과 같은 방식으로 얼럿을 띄운다("다시 시도" / "확인").
  다시 시도해도 실패하면 얼럿이 또 뜬다 — 성공할 때까지 복구 경로가 남는다
- 사진만 실패하면 얼럿을 띄우지 않는다. 상세가 성공했으면 화면 대부분이 그려져 있고,
  상세까지 실패했다면 그 얼럿의 "다시 시도"가 사진도 함께 부른다
- 상세 조회가 성공했고 방이 인화 완료면 확인을 서버에 기록한다(`CheckPrintCompletionUseCase`) —
  다음 홈 조회부터 이 방이 하단 "인화 완료" 목록으로 옮겨진다
  - 홈이 아니라 상세가 부르는 이유: 화면 전환으로 홈 State가 사라지면 걸어 둔 이펙트도
    취소돼 요청이 유실됐다. 도착한 화면이 부르면 수명이 요청과 같이 간다
  - 실패해도 알리지 않는다 — 다음 진입에서 다시 기록된다. 같은 상세에서 두 번 보내지 않게
    `hasReportedPrintCompletionCheck`로 1회 제한

### RoomDetailView

- `RoomDetailView(store:)` — `@ViewAction`으로 뷰 액션을 보낸다
- 카운트다운은 State에 두지 않는다. `TimelineView`가 `photoPrintCompletedAt`에서 매초 계산한다 —
  초마다 상태를 바꾸면 화면 전체가 다시 그려지고 테스트에 타이머가 섞인다

### RoomSettingsFeature / RoomSettingsView (`Sources/Settings/`)

- `State(roomID:title:)` — 방 이름 행의 값과 이름 수정 드로어(`@Presents rename`)를 든다.
  이름 수정이 성공하면 행 값이 갱신된다
- `Action.delegate` — `closeTapped`(뒤로) · `coverEditRequested`(커버 수정 화면 — #69에서 App이 연결)
- 상세 ↔ 설정 전환은 App이 한다. 돌아갈 때 App이 설정의 최신 제목으로 `Room`을 다시 조립해
  (`Room.renamed(to:)`) 재조회가 오기 전에도 새 이름이 보인다

### RenameRoomFeature / RenameRoomDrawer

- `State(roomID:title:)` — 현재 이름이 미리 채워진다. `canSubmit`은 요청 중이 아니고
  규칙에 맞는 이름이며 실제로 달라졌을 때만 참이다
- 타이핑은 `BindingReducer`가 20자로 자르고, 제출은 `UpdateRoomTitleUseCase`가 규칙을 적용한다 —
  방 만들기와 같은 규칙(`RoomNameRule`) 하나를 쓴다
- 성공하면 `delegate(.renamed(정제된 이름))`만 보낸다 — 행 값 갱신과 드로어 닫기는 부모(방 설정)가 한다

### CopyToPasteboard

- 초대 코드 복사용 의존성. `UIPasteboard` 싱글턴 직접 접근을 막으려고 감쌌다(규칙: `@Dependency`로 주입)
- `liveValue`만 채워져 있다 — Data 접근이 없는 OS 호출 한 줄이라 합성 루트 조립이 필요 없다.
  `testValue`는 미구현이라 테스트가 갈아끼우지 않고 호출하면 실패로 드러난다

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `PhotoDomain` · `ShootEntry`(촬영 진입 준비) ·
  `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `CHALLAApp`(조립) · `RoomDetailFeatureDemo`(데모)

## 알려진 미구현

- **툴팁** — 시안(5604:19130)의 "초대 코드로 친구를 초대해보세요"가 빠져 있다.
  디자인 시스템에 Tooltip 컴포넌트가 없어 담당자 확인 후 추가한다
- **카운트다운 0초 도달 뒤 서버 전환 지연** — 0초에 도달하면 상세·사진을 재조회한다
  (완료 예정 시각에 한 번 깨어나는 알람 이펙트). 재조회 결과가 여전히 인화 대기면
  `0:00:00`을 유지하고 알람은 다시 걸지 않는다 — 그 공백의 처리(재시도 간격 등)는 기획 확인 필요

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomDetailFeature
```

TCA `TestStore`로 리듀서를 검증한다 — 진입 조회(상세+사진), 실패 얼럿과 재시도,
클립보드 복사와 토스트 타이머(`TestClock`), delegate 위임, 카운트다운 표기 규칙.
`RoomDetailShootEntryTests`는 촬영 진입만 따로 본다 — 준비 중 표시와 재탭 무시, 성공 시 delegate,
실패 얼럿과 설정 열기. 준비 자체(권한 순서·실패 판단)는 `ShootEntry` 테스트가 본다.

화면 확인은 데모앱으로 한다. 상태별로 실행 인자를 받는다:

```bash
xcrun simctl launch booted com.challa.roomdetailfeature.demo \
  --screen detail --state <shooting|shootingPartial|printWaiting|printed|invite|error>
```

데모앱에는 카메라 화면이 없어 사진 찍기는 진입 요청(delegate)까지가 끝이다 —
버튼이 로딩으로 바뀌었다 풀리는 것까지만 보인다. 권한도 값으로 갈아끼워 시스템 팝업이 뜨지 않는다.
