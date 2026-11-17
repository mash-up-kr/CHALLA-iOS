# CHALLA 네비게이션 · 화면 연결 (프로젝트 규칙)

> TCA 공식 패턴(`navigation-basics.md` · `presentation.md`) 위에 CHALLA가 정한 규칙이다.
> #126 리팩토링(화면 교체 → 스택)에서 겪고 정했다. 짧은 버전은 `.claude/rules/tca-feature.md` "네비게이션" 절.

## 구조 한 장

```
AppFeature   앱 맨 위. 돌아갈 일 없는 큰 흐름만 enum으로 교체한다
├ launching · login · profileSetup · forceUpdate
└ main ──── MainFeature   로그인 뒤 화면 전부
             ├ home    스택 맨 아래. 항상 있다
             ├ path    StackState<Path> — 옆에서 밀려 오는 화면들
             └ (@Presents)  아래에서 덮는 화면 (카메라 등)
```

- `MainView`가 앱에서 **유일한** `NavigationStack`이다.
- 아직 옮기지 않은 화면(#127 카메라 · #128 설정·프로필 편집)은 AppFeature enum에 남아 있고, 메인과는 임시 연결 코드(`returnToMain`, "메인에서 enum 화면으로 나가는 요청" 블록)로 이어져 있다.

## 어떤 방식으로 띄우나

| 화면 모양 | 방식 | 예 |
| :-- | :-- | :-- |
| 옆에서 밀려 오는 전체 화면 (뒤로가기 있음) | `MainFeature.Path`에 쌓기 | 방 상세 · 사진 상세 · 채팅 · 방 설정 · 커버 수정 |
| 아래에서 올라와 덮는 전체 화면 | `@Presents` + `.fullScreenCover` | 카메라 (#127) |
| 드로어 · 시트 · 얼럿 | 그 화면 Feature 안의 `@Presents` | 방 이름 수정 · 방 만들기 · 입장 |
| 돌아갈 일 없는 흐름 전환 | AppFeature enum 교체 | 스플래시 → 로그인 → 메인 |

## 규칙

### 1. Feature는 스택을 모른다 — delegate로 알리기만 한다

```swift
// 자식 Feature: 열어 줘 / 닫아 줘 / 바뀌었어 를 알리기만
case .view(.settingsButtonTapped):
    return .send(.delegate(.settingsTapped))

// MainFeature: 받아서 쌓고 뺀다
case let .path(.element(id: id, action: .roomDetail(.delegate(.settingsTapped)))):
    guard case let .roomDetail(detail) = state.path[id: id] else { return .none }
    state.path.append(.roomSettings(RoomSettingsFeature.State(roomID: detail.room.id, title: detail.room.title)))
    return .none

case let .path(.element(id: id, action: .roomSettings(.delegate(.closeTapped)))):
    state.path.pop(from: id)
    return .none
```

- `.path(.element(id:, action:))` = "스택의 id번 화면이 보낸 액션". `state.path[id: id]`로 그 화면 State를 꺼낸다.
- Feature끼리는 서로 import하지 않는다 (규칙 3). 쌓을 화면의 State는 MainFeature가 만든다.

### 2. Feature 뷰 안에 `NavigationStack`을 두지 않는다

스택 안에 스택이 생기면 SwiftUI 네비게이션이 깨진다. 하위 화면이 필요하면 delegate로 요청하고 MainFeature가 같은 스택에 쌓는다. (설정이 지금 자체 스택을 가진 예외 — #128에서 제거)

스택 안 화면은 전부 `CHALLATopNavigation`을 직접 그린다. 시스템 바는 `MainView`가 숨기고, 숨기면 꺼지는 스와이프 뒤로가기는 `InteractivePopGestureEnabler`가 루트에서 한 번 켠다. 화면마다 따로 할 일은 없다.

### 3. 이전 화면 데이터를 들고 다니지 않는다 — 부모가 꺼낸다

아래 화면은 스택에 살아 있다. 새 화면에 필요한 값은 **부모가 스택 아래 화면 State에서 꺼내** 넘긴다.

```swift
// 커버 수정에 필요한 인원수·커버는 방 설정이 아니라 스택 아래 방 상세에서
guard case let .roomSettings(settings) = state.path[id: id],
      let detail = state.roomDetail(roomID: settings.roomID) else { return .none }
state.path.append(.roomCoverEdit(RoomCoverEditFeature.State(
    roomID: settings.roomID, title: settings.title,
    memberCount: detail.detail?.members.count ?? state.home.cards[id: settings.roomID]?.memberCount ?? 0,
    cover: detail.room.cover
)))
```

"돌아갈 때 쓸 값"을 담는 포장 struct(`XxxScreen`)는 만들지 않는다. 그건 화면을 갈아끼우던 옛 방식의 부산물이다.

### 4. 위에서 바꾼 값은 부모가 아래 화면에 반영한다

아래 화면은 새로 만들어지지 않으므로 저절로 최신이 되지 않는다. 부모가 같은 액션을 엿보고 고친다.

```swift
// 이름 수정 드로어의 renamed — 방 설정도 받고, MainFeature도 받는다
case let .path(.element(id: id, action: .roomSettings(.rename(.presented(.delegate(.renamed(name))))))):
    guard case let .roomSettings(settings) = state.path[id: id] else { return .none }
    state.updateRoom(id: settings.roomID) { $0.renamed(to: name) }
    return .none
```

- `updateRoom(id:_:)`은 "그 방을 들고 있는 곳(스택 안 방 상세 전부 · 홈 카드)"을 한 번에 고친다. 무엇을 바꿀지는 클로저로 넘긴다 (`{ $0.withCover(cover) }` 등).
- 서버가 저장한 값이 액션에 실려 오면 **다시 조회하지 않는다.**
- 스택 원소·카드는 값 타입이다. 꺼내 고친 뒤 같은 자리에 다시 넣는다.

### 5. 닫힐 때 읽을 값은 빼기 전에 읽는다

```swift
case let .path(.element(id: id, action: .roomCoverEdit(.delegate(.closeTapped)))):
    guard case let .roomCoverEdit(edit) = state.path[id: id] else { return .none }
    state.updateRoom(id: edit.roomID) { $0.withCover(edit.savedCover) }   // 먼저 읽고 반영
    state.path.pop(from: id)                                                // 그다음 뺀다
    return .none
```

`pop(from:)`을 먼저 하면 원소가 사라져 값을 못 읽는다.

### 6. 스와이프로 닫힐 때 할 일은 `.popFrom(id:)`에서

스와이프는 화면의 뒤로 버튼을 거치지 않는다. NavigationStack이 `.path(.popFrom(id:))`를 보내고, **부모 Reduce가 먼저 받은 뒤 `.forEach`가 원소를 뺀다.** 그래서 여기서는 아직 편집값을 읽을 수 있다.

```swift
case let .path(.popFrom(id: id)):
    guard case let .roomCoverEdit(edit) = state.path[id: id], edit.hasChanges else { return .none }
    state.updateRoom(id: edit.roomID) { $0.withCover(edit.cover) }        // 먼저 보여 주고
    return .run { [useCase, roomID = edit.roomID, cover = edit.cover, previous = edit.savedCover] send in
        do {
            try await useCase.run(roomID, RoomCoverDraft(cover: cover))
            await send(.roomCoverSaved(roomID: roomID, cover: cover))      // 성공 → 한 번 더 반영 (규칙 8)
        } catch {
            await send(.roomCoverSaveFailed(roomID: roomID, previousCover: previous))  // 실패 → 되돌림
        }
    }
```

`.run`의 캡처 리스트로 값을 복사해 간다. 비동기로 도는 시점엔 원소가 이미 빠져 `state`에서 읽을 수 없다.

### 7. 아래 화면이 다시 보이면 `.task`가 다시 돈다

SwiftUI `.task`는 화면이 **보일 때마다** 시작하고 가려지면 취소된다. 스택에서 위 화면이 빠지면 아래 화면의 `.task`가 다시 돌아 조회를 다시 한다 (홈 · 방 상세). State는 유지되고 목록이 있으면 스피너도 없다.

- 한 번만 불러와야 하는 화면이면 리듀서에 "이미 불러옴" 가드를 둔다.
- TestStore는 뷰 수명주기를 모른다 — 이 재실행은 리듀서 테스트에 안 잡힌다. 실기기로 확인한다.

### 8. 저장이 끝나기 전에 화면이 닫히면, 성공했을 때 한 번 더 반영한다

규칙 6처럼 저장을 맡기고 바로 닫으면, 아래 화면의 재조회(규칙 7)와 저장 요청이 동시에 나간다. 서버가 **재조회를 먼저 처리하면 옛 값**이 와서 아래 화면을 덮는다. 저장 성공 시점에 한 번 더 반영하면 어떤 순서로 처리돼도 마지막 값이 맞다.

뒤로 버튼처럼 **저장이 끝난 뒤 닫히는** 경로는 해당 없다.

## 화면 하나를 스택으로 옮기는 순서

1. `MainFeature.Path`에 case 한 줄
2. `MainView` destination switch에 한 줄
3. 그 화면을 여는 delegate를 MainFeature에서 받아 `path.append`
4. 닫는 delegate를 받아 `path.pop(from: id)` (닫을 때 읽을 값이 있으면 규칙 5)
5. AppFeature의 연결 코드 삭제 → 옛 enum case · 포장 struct 삭제 (자기 PR에서)
6. `MainFeatureTests`에 열기 · 닫기 · "아래 화면 그대로" 테스트

커밋은 "새 것을 옆에 추가 → 연결을 하나씩 옮김 → 아무도 안 쓰게 된 옛 것 삭제" 순서로, 커밋마다 빌드·테스트가 통과하게 나눈다.

## 테스트 함정

### 스택 원소 id를 손으로 넣지 않는다

테스트의 `StackElementID`는 생성기가 테스트 함수마다 0부터 발급한다. `path[id: 0] = …`로 넣으면 생성기가 모르고 같은 번호를 다시 발급해 **덮어쓴다.**

```swift
// ❌ 리듀서가 append할 때 또 0번을 받아 방 상세 자리를 덮는다
state.path[id: 0] = .roomDetail(...)

// ✅ append로 쌓아 번호를 소비시키고, id는 읽어서 쓴다
state.path.append(.roomDetail(...))
let detailID = try #require(store.state.path.ids.first)
let chatID: StackElementID = 1          // 다음에 쌓일 원소는 다음 번호
```

- 스택 id를 기대하는 테스트에 `@Test(arguments:)`를 쓰지 않는다. 실행끼리 생성기를 나눠 써 번호가 흔들린다 — 한 함수 안 루프로 돌린다.
- `store.dependencies.stackElementID.peek()`는 SPI라 쓸 수 없다. 정수 리터럴이 공식 방법이다.

### 드로어·시트 안 액션은 그 State를 열어 둔 채로 보낸다

`@Presents` 자식의 `.presented(...)` 액션을 보낼 때 그 State가 `nil`이면 TCA가 "received a presentation action when destination state was absent"로 실패시킨다. 실제 앱에서도 열려 있을 때만 오는 액션이니 초기 State에서 열어 둔다.

### `@Reducer enum Path`의 `State`에 `Equatable`을 직접 붙인다

```swift
extension MainFeature.Path.State: Equatable {}
```

매크로가 붙여 주지 않는다. TestStore가 매 `send`마다 기대 State와 실제 State를 `==`로 비교하므로, 바깥 State가 Equatable이려면 안쪽 `Path.State`도 필요하다.

### `.ifCaseLet` 체인이 길면 타입 추론 시간 초과

case가 많아 "unable to type-check this expression in reasonable time"이 나면 앞 토막을 `private var`로 끊어 체인을 나눈다.
