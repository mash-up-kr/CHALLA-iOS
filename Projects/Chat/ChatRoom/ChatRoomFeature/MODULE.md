# ChatRoomFeature

**Feature 레이어(TCA)**. 방 채팅 화면(개별 상세) — 메시지 목록 조회·전송·실시간 수신. 서버는 모르고 `ChatDomain`의 UseCase를 쓴다.

## 공개 API

- `ChatRoomFeature` (`@Reducer`)
  - `State` — `roomID` · `roomTitle` · `currentUserID` · `currentUserNickname` · `isPrinted` · 메시지/페이지/실시간 연결 상태.
    `init(roomID:roomTitle:currentUserID:currentUserNickname:isPrinted:)`
  - `Action` — `view(task · backButtonTapped · draftChanged · sendTapped · reachedTop · scrollToBottomTapped · bottomVisibilityChanged)` · 조회/수신/전송 결과 · `delegate(closeRequested)` · `alert`
- `ChatRoomView` — `init(store:)`

## 동작 규칙

- **인화 전에는 채팅에 붙은 사진도 blur로 가린다** (`isPrinted == false`). 방 상세 필름카드와 같은 연출·같은 강도(13.5)라
  같은 사진이 화면마다 다르게 보이지 않는다. 방 상태는 App이 조립할 때 넘긴다
- 진입 시 첫 페이지(size 30)를 조회하고, 위로 스크롤해 맨 위에 닿으면 이전 페이지를 더 불러와 목록 위에 붙인다.
  `ChatPage.hasMore`를 따르며, 매핑된 항목이 빈 페이지도 `nextPage`를 전진시킨다. 붙이기 전 맨 위 메시지로 스크롤을 되돌려 위치를 유지한다
- 전송은 빈 입력·전송 중 재탭을 무시하고, 낙관적으로 입력창을 비운 뒤 목록에 `.local` id로 먼저 붙인다.
  전송 응답의 `chatId`가 오면 그 자리에서 `.server` id로 **확정**해, 뒤이어 오는 소켓 에코가 같은 키로 접힌다
- 화면 닫기는 App이 한다(규칙 3) — `delegate(.closeRequested)`만 보낸다

## 진입 순서 — 구독 → 조회 → 병합

`.view(.task)`가 **구독 확정 → 과거 목록 조회 → 병합** 순서로 돈다. 백엔드가 정한 채팅 누락 방지 순서다.
`ObserveChatsUseCase`가 구독이 확정된 뒤에야 리턴하므로 이 순서는 타입으로 강제된다 — 조회를 먼저 하면
조회와 구독 사이에 온 메시지가 어디에도 남지 않는다.

- `.subscribed` — 구독 확정(첫 연결·재연결 공통). 최초에는 첫 페이지를, 재연결에는 이전 REST 기준점과 겹칠 때까지 연속 조회한다
- `.received(ChatMessage)` — 소켓 메시지를 목록에 병합
- `.subscribeFailed` — 얼럿 없이 REST로 보완하고 정해진 횟수만큼 구독을 다시 시도한다.
  실시간이 없어도 화면은 동작해야 하므로 사용자에게 실패를 알리지 않는다
- `chatsResponse`는 목록을 **교체하지 않고 병합**한다. 조회 중 온 소켓 메시지를 덮지 않기 위해서다
- 직전 최신 REST 페이지의 id만 복구 기준으로 보관한다. 소켓 한 건이나 REST 전송 응답을 기준으로 삼으면
  그 사이 공백을 놓친다

## 화면 (Zeplin "개별 상세", 다크 테마)

- 상단 `CHALLATopNavigation.sub` + 하단 노란 글로우(PhotoDetailView 패턴). 색은 `CHALLAColor` 토큰 매핑
  (surface #111111 · level2 #242424 · level4 #3B3B3B · Label.normal/neutral)
- 메시지 행(`ChatMessageRow`): 받은 메시지는 좌측(아바타 22 + 이름 + `#3B3B3B` 버블), 내 메시지는 우측(흰 버블, 아바타·이름 없음), 사진 메시지는 필름카드(82×109.33). 날짜가 바뀌면 구분선.
  내 메시지 판정은 `currentUserID` 비교다 — 닉네임으로 보면 동명이인이 서로의 말풍선을 뺏는다
- **새 메시지가 와도 자동으로 내리지 않는다.** 위를 읽던 사람의 화면을 뺏기 때문이다.
  대신 맨 아래가 아닐 때 새 메시지가 오면 "맨 아래로" 버튼이 뜨고, 누르면 그때 내려간다.
  맨 아래 여부는 목록 끝의 1pt 센티널이 보이는지로 판단한다(`bottomVisibilityChanged`)
- 입력창(`ChatInputBar`): `CHALLATextField`(포커스 시 라임 테두리·왼쪽 정렬) + 포커스/입력 시 전송 버튼(32×32). 리턴(`.send`)·버튼 탭으로 전송
  - **미해결**: 전송 화살표는 시안의 `arrow_upward`지만 CHALLAIcon에 에셋이 없어 SF Symbol로 대체 — DS 아이콘 추가 후 교체
- 진입 훅은 `.onAppear`가 아니라 `.task`다. 구독은 화면이 살아 있는 동안만 도는 장수 이펙트라
  화면을 벗어날 때 함께 정리돼야 한다

## 의존성

- **이 모듈이 의존**: `ChatDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `CHALLAApp` · `ChatRoomFeatureDemo`

## 테스트

- `ChatRoomFeatureTests` — 진입 로드, 조회 실패 얼럿, 전송 후 입력창 비우고 덧붙이기, 공백 메시지 무시, 뒤로가기 delegate
- `ChatRoomRealtimeTests` — 구독→조회 순서, 소켓 메시지 병합, 전송 응답의 `chatId` 확정, 재연결 시 공백 메우기, 구독 실패 재시도, 맨 아래로 버튼 노출 조건
