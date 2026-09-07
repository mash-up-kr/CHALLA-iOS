# ChatDomain

**Domain 레이어**. 방 채팅 aggregate — 메시지 조회·작성. 서버·네트워크는 모른다(구현은 `ChatData`).

## 공개 API

### Entities

| 타입 | 내용 |
| :-- | :-- |
| `ChatMessage` | `id: ChatMessageID` · `kind` · `content` · `photoImageURL?` · `authorID` · `authorName` · `authorImageURL?` · `createdAt`. `isMine(currentUserID:)`로 내 메시지를 판별한다 |
| `ChatMessage.Kind` | `.text` · `.photo` · `.reaction(ReactionKind)` |
| `ChatPage` | 매핑된 `messages`와 서버 원본 개수에서 계산한 `hasMore`, `nextPage`, 재연결 기준 `anchorIDs`를 담는 페이지 |

### Errors

- `ChatError` — `network` · `unauthorized` · `server(message:)` · `unknown`. `userMessage`로 얼럿 문구를 들고 다닌다 (`PhotoError`와 같은 구조)

### Interface

- `protocol ChatRepository` — `messages(inRoom:page:size:) -> ChatPage` · `send(roomID:photoID:content:)`(작성, 생성된 chatId(`Int64?`) 반환). 실패는 `ChatError`로 정규화

### UseCases (`DependencyValues` 키 — `liveValue` 없음)

| 키 | live | 설명 |
| :-- | :-- | :-- |
| `\.fetchChatsUseCase` | `.live(repository:)` | 방의 채팅을 페이지 단위로 가져온다 |
| `\.sendChatUseCase` | `.live(repository:)` | 메시지를 보내고 생성된 채팅을 돌려준다(화면이 낙관적으로 덧붙임). 방 단위 텍스트는 `photoID`가 nil |

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros`
- **이 모듈에 의존**: `ChatData`(구현) · `ChatRoomFeature`(UseCase 키) · `PhotoDetailFeature`(사진 상세에서 `sendChatUseCase`) · `CHALLAApp`(조립)

## 테스트

- `ChatUseCaseTests` — 방/사진/내용 인자 전달, 실패 전파
- `ChatMessageTests` — 닉네임 일치로 내 메시지 판별, 빈 닉네임 오판 방지

## 실시간 수신 (추가)

- `protocol ChatEventStreaming` — `chatEvents(roomID:)`. 구독이 확정된 뒤 리턴한다.
- `enum ChatStreamEvent` — `.message(ChatMessage)` · `.resumed`
- `ObserveChatsUseCase` — 위 스트림을 Feature에 넘긴다
- `enum ChatMessageID` — `.server(Int64)`(서버 chatId) · `.local(UUID)`(전송 중인 낙관적 메시지).
  `ChatMessage.ID`로도 쓸 수 있다.
- `ChatMessage.authorID` — 서버의 `userId`. `isMine(currentUserID:)`이 이 값으로 판정한다(닉네임 비교 폐기).
- `ChatMessage.promoted(toServerID:)` — 전송 응답의 chatId로 낙관적 메시지를 확정한다.
- `ChatMessage.merged(_:with:)` — 목록 병합. 같은 id는 새로 받은 쪽이 이기고, 정렬 키는 `(createdAt, 서버 id)`다.
- `ChatRepository.send`가 `Int64?`(생성된 chatId)를 돌려준다.

조회·전송(`ChatRepository`)과 수신(`ChatEventStreaming`)을 나눈 이유는 수명주기와 실패 양상이 다르고,
기존 Mock 구현들이 쓰지도 않을 메서드를 떠안지 않게 하려는 것이다.
