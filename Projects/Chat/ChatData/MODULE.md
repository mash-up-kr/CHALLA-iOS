# ChatData

**Data 레이어**. `ChatRepository`의 실서버 구현. 실패는 전부 `ChatError`로 정규화해 던진다.

## 공개 API

- `struct DefaultChatRepository: ChatRepository` — `init(client:)`
  - `messages(inRoom:page:size:)` — `GET /api/v1/chats/{roomId}?page=&size=` → 도메인 변환.
    `photoImageUrl` 유무로 사진/텍스트를 가른다. 서버가 메시지 id를 안 줘 매핑에서 UUID를 생성하고,
    보낸 사람 이름이 없는 항목은 건너뛴다
  - `send(roomID:photoID:content:)` — `POST /api/v1/chats`(`type: "DEFAULT"`). 생성된 채팅을 도메인으로 돌려준다.
    방 단위 텍스트는 `photoID`가 nil → 서버 예시대로 `photoId: 0`으로 보낸다(백엔드 확인 필요)

## 내부 구성

- `DTO/` — `BaseResponseDTO`(공통 껍데기, `ChatError` 던짐) · `SendChatRequestDTO` · `ChatMessageDTO`(목록·응답 공통) · `ListChatsResponseDTO` · `SendChatEnvelopeDTO`
- `Endpoint/ChatEndpoint` — `.send` · `.list` (bearer). PhotoData 내부 `ChatEndpoint`(리액션)와 이름이 같지만 다른 모듈·internal
- `Mapping/` — `ChatMessage+Mapping`(+ `ServerDate` UTC 파서 복사본, #51 이후 공용화) · `ChatError+Mapping`(NetworkError→도메인)

## 의존성

- **이 모듈이 의존**: `ChatDomain` · `CHALLANetwork`
- **이 모듈에 의존**: `CHALLAApp`(조립 지점에서만)

## 테스트

- `DefaultChatRepositoryTests` — 목록 경로·쿼리, 사진/텍스트 매핑, 이름 없는 항목 건너뛰기, POST 본문(`{chat:{roomId,photoId,type,content}}`), nil photoID → 0, 오류 정규화(network·401)
