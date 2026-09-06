# ChatRoomFeature

**Feature 레이어(TCA)**. 방 채팅 화면(개별 상세) — 메시지 목록 조회 + 전송. 서버는 모르고 `ChatDomain`의 UseCase 두 개만 쓴다.

## 공개 API

- `ChatRoomFeature` (`@Reducer`)
  - `State` — `roomID` · `roomTitle` · `currentUserNickname`(내 메시지 판별) · `isPrinted`(인화 완료 여부) ·
    `messages: [ChatMessage]` · `draft` · `isLoading` · `isSending` · `alert`.
    `init(roomID:roomTitle:currentUserNickname:isPrinted:)`
  - `Action` — `view(onAppear · backButtonTapped · draftChanged · sendTapped)` · `chatsResponse` · `sendResponse` · `delegate(closeRequested)` · `alert`
- `ChatRoomView` — `init(store:)`

## 동작 규칙

- **인화 전에는 채팅에 붙은 사진도 blur로 가린다** (`isPrinted == false`). 방 상세 필름카드와 같은 연출·같은 강도(13.5)라
  같은 사진이 화면마다 다르게 보이지 않는다. 방 상태는 App이 조립할 때 넘긴다

- 진입 시 첫 페이지(size 30)를 조회하고, 위로 스크롤해 맨 위에 닿으면 이전 페이지를 더 불러와 목록 위에 붙인다.
  서버 응답에 `hasNext`가 없어 "받은 개수 == size"로 더 있는지 가늠한다. 붙이기 전 맨 위 메시지로 스크롤을 되돌려 위치를 유지한다
- 전송은 빈 입력·전송 중 재탭을 무시하고, 낙관적으로 입력창을 비운 뒤 서버가 돌려준 메시지를 목록에 덧붙인다
- 화면 닫기는 App이 한다(규칙 3) — `delegate(.closeRequested)`만 보낸다

## 화면 (Zeplin "개별 상세", 다크 테마)

- 상단 `CHALLATopNavigation.sub` + 하단 노란 글로우(PhotoDetailView 패턴). 색은 `CHALLAColor` 토큰 매핑
  (surface #111111 · level2 #242424 · level4 #3B3B3B · Label.normal/neutral)
- 메시지 행(`ChatMessageRow`): 받은 메시지는 좌측(아바타 22 + 이름 + `#3B3B3B` 버블), 내 메시지는 우측(흰 버블, 아바타·이름 없음), 사진 메시지는 필름카드(82×109.33). 날짜가 바뀌면 구분선
- 입력창(`ChatInputBar`): `CHALLATextField`(포커스 시 라임 테두리·왼쪽 정렬) + 포커스/입력 시 전송 버튼(32×32). 리턴(`.send`)·버튼 탭으로 전송
  - **미해결**: 전송 화살표는 시안의 `arrow_upward`지만 CHALLAIcon에 에셋이 없어 SF Symbol로 대체 — DS 아이콘 추가 후 교체

## 의존성

- **이 모듈이 의존**: `ChatDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `CHALLAApp` · `ChatRoomFeatureDemo`

## 테스트

- `ChatRoomFeatureTests` — onAppear 로드, 조회 실패 얼럿, 전송 후 입력창 비우고 덧붙이기, 공백 메시지 무시, 뒤로가기 delegate

## 실시간 수신 (추가)

진입(`.view(.task)`)이 **구독 확정 → 과거 목록 조회 → 병합** 순서로 돈다. 백엔드가 정한 채팅 누락 방지 순서다.
`ObserveChatsUseCase`가 구독이 확정된 뒤에야 리턴하므로 순서가 타입으로 강제된다.

- `.subscribed` — 구독 확정(첫 연결·재연결 공통) → 첫 페이지 재조회
- `.received(ChatMessage)` — 소켓 메시지를 목록에 병합
- `.streamEnded` — 소켓 포기. 얼럿 없이 REST만으로 계속 돈다
- `chatsResponse`가 목록을 **교체하지 않고 병합**한다. 조회 중 온 소켓 메시지를 덮지 않기 위해서다
- `State.currentUserID` 추가 — `isMine` 판정이 닉네임에서 userId로 바뀌었다
- 뷰의 진입 훅이 `.onAppear`에서 `.task`로 바뀌었다 (장수 이펙트를 화면 이탈 시 정리해야 한다)
