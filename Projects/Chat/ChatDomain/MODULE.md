# ChatDomain

**Domain 레이어**. 방 채팅 aggregate — 메시지 조회·작성. 서버·네트워크는 모른다(구현은 `ChatData`).

## 공개 API

### Entities

| 타입 | 내용 |
| :-- | :-- |
| `ChatMessage` | `id: UUID`(서버가 id를 안 줘 매핑/전송 시 생성) · `kind`(`.text`/`.photo`) · `content` · `photoImageURL?` · `authorName`(응답 userName) · `authorImageURL?` · `createdAt`. `isMine(currentUserNickname:)`로 내 메시지(오른쪽 흰 버블)를 판별한다 — 서버가 userId를 주면 id 비교로 교체 예정 |
| `ChatMessage.Kind` | `.text` · `.photo` (photoImageURL 유무로 결정) |

### Errors

- `ChatError` — `network` · `unauthorized` · `server(message:)` · `unknown`. `userMessage`로 얼럿 문구를 들고 다닌다 (`PhotoError`와 같은 구조)

### Interface

- `protocol ChatRepository` — `messages(inRoom:page:size:)`(목록) · `send(roomID:photoID:content:)`(작성, 생성된 메시지 반환). 실패는 `ChatError`로 정규화

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
