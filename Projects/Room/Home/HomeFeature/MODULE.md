# HomeFeature

## 레이어와 책임

**Feature 레이어**. 홈(방 목록) 화면과 그 위에 겹쳐 뜨는 방 만들기 · 초대 코드 입장 드로어를 담는다.
TCA로 작성하며 `RoomDomain`의 UseCase를 `@Dependency`로 주입받는다 — `RoomData`는 import하지 않는다
(아키텍처 규칙 2).

**화면 전환은 하지 않는다.** 방 상세·설정으로 가는 것은 App의 몫이라 `delegate` 액션으로 넘긴다
(규칙 3: Feature끼리 직접 참조하지 않는다).

**부모/자식 책임 분리**: 두 드로어는 각자 리듀서를 갖고, 성공을 `delegate`로 알리기만 한다.
드로어를 닫고 목록에 반영하는 것은 홈이 한다 — 목록은 홈의 State라 자식이 손댈 수 없고,
닫기와 반영이 한 리듀서 패스 안에서 끝나야 목록에 안 들어간 채 드로어만 닫히는 중간 상태가 없다.
실패 얼럿은 반대로 자식이 소유한다 — 드로어를 연 채 입력값 그대로 다시 시도할 수 있어야 한다.

## 공개 API

App(또는 데모앱)이 쓰는 것만 열려 있다. 드로어 뷰와 내부 컴포넌트는 `internal`이다.

- `struct HomeView: View` — `init(store:)`
- `@Reducer struct HomeFeature`
  - `State(nickname:profileImageURL:)` — 닉네임은 필수다. 사용자 정보를 다루는 Domain이 아직 없어
    부모가 넣어 준다. 이슈 #33이 프로필 정본을 만들면 UseCase 주입으로 바꾼다
  - `Action.Delegate` — `.roomSelected(Room)` · `.roomCreated(Room)` · `.roomJoined(Room)` · `.settingsTapped`

`CreateRoomFeature` · `JoinRoomFeature`는 `Destination`에 담기느라 `public`이지만 App이 직접 쓰지 않는다.

### 화면 상태

`fetchRooms` 한 번의 결과에서 네 가지가 파생된다. 판단은 전부 State에 있고 뷰는 골라 그리기만 한다.

- `showsLoading` — 첫 조회 중. 재조회 중에는 보던 목록을 유지한다
- `errorMessage` — 조회에 실패했고 보여줄 목록도 없을 때의 안내 문구
- `showsEmptyState` — 조회를 마쳤는데 방이 없을 때
- `board` — 그 외. `RoomBoard`가 촬영 중 · 촬영 완료 두 섹션으로 가른다

### 겹쳐 뜨는 것

`@Presents var destination`에 enum 하나로 묶는다 — 드로어와 얼럿은 동시에 뜰 수 없고,
옵셔널 둘로 두면 둘 다 떠 있는 상태를 코드로 만들 수 있지만 enum은 타입이 막는다.

상단 `+` 메뉴만 `isPlusMenuPresented` Bool이다. 자식 리듀서도, 닫힐 때 취소할 이펙트도 없어
`@Presents`가 해 줄 일이 없다.

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `CHALLADesignSystem` · `ComposableArchitecture`
- **이 모듈에 의존**: `HomeFeatureDemo` · (예정) `CHALLAApp`

## 알려진 임시 구현

- 얼럿 제목·버튼 문구, 조회 실패 화면의 문구·레이아웃은 임의 작성본이다 (기획 가이드 대기)
- 중복 입장 시 서버 동작이 미확정이라 `updateOrInsert`로 가정한다.
  서버가 에러를 주면 그 처리는 얼럿으로 옮긴다

## 테스트 실행 방법

```bash
mise exec -- tuist test HomeFeature
```

Swift Testing + TCA `TestStore` 기반. 시뮬레이터가 필요하다 (`@MainActor` 스위트).

- `HomeFeatureTests` — 조회·빈 상태·실패 얼럿과 재시도, 목록이 있는 재조회 실패는 본문을 안 건드리는지,
  드로어가 열려 있으면 얼럿으로 덮지 않는지, 취소된 조회가 재개되는지,
  카드 탭·설정의 delegate 위임, `+` 메뉴에서 두 드로어 진입, 생성·입장 결과의 목록 반영
  (재입장은 중복 없이 값만 갱신)
- `CreateRoomFeatureTests` — 20자 자르기, 버튼 잠금 조건, 매수 선택, 성공 delegate,
  가드 2종(빈 이름·요청 중), 실패 얼럿 후 입력값 유지, 닫기의 dismiss
- `JoinRoomFeatureTests` — 버튼 잠금 조건, 입력 중 공백을 지우지 않는지, 성공 delegate,
  가드 2종, `.roomNotFound` 얼럿 후 입력값 유지, 닫기의 dismiss

화면 상태별 UI 확인은 `HomeFeatureDemo`가 맡는다 — 실행 인자로 목록 6상태와 드로어를 바로 띄운다.
