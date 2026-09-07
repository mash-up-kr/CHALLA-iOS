# ChatData

**Data 레이어**. `ChatRepository`의 실서버 구현. 실패는 전부 `ChatError`로 정규화해 던진다.

## 공개 API

- `struct DefaultChatRepository: ChatRepository` — `init(client:)`
  - `messages(inRoom:page:size:)` — `GET /api/v1/chats/{roomId}?page=&size=` → 도메인 변환.
    `photoImageUrl` 유무로 사진/텍스트를 가른다. 서버 ID나 보낸 사람 정보가 없는 항목은 건너뛴다.
    반환하는 `ChatPage.hasMore`는 매핑 후 개수가 아니라 원본 DTO 개수로 계산해, 잘못된 항목 때문에 페이지가 조기 종료되지 않게 한다
  - `send(roomID:photoID:content:)` — 사진에 보낸 메시지는 `POST /chats/reaction`(`COMMENT`),
    방 단위 메시지는 `POST /chats`(`DEFAULT`) (아래 "채팅 종류"). 생성된 채팅을 도메인으로 돌려준다.
    방 단위 텍스트는 `photoID`가 nil → 서버 예시대로 `photoId: 0`으로 보낸다(백엔드 확인 필요)

## 채팅 종류

서버는 채팅 하나로 세 가지를 다룬다 — 종류에 따라 화면이 다르게 그린다.

| `type` | 경로 | 보내는 곳 | 화면 |
| :-- | :-- | :-- | :-- |
| `DEFAULT` | `/chats` | 방 채팅 (붙일 사진 없음) | 텍스트 버블 |
| `COMMENT` | `/chats/reaction` | 사진 상세 | 사진 + 글 |
| `EMOJI` | `/chats/reaction` | 사진 리액션 (PhotoData가 보낸다) | 사진 + 이모지 스티커 |

인화 전 방에서는 채팅에 붙은 사진도 **blur로 가린다** — 방 상세 필름카드와 같은 연출·같은 강도(13.5)다.
`ChatRoomFeature.State.isPrinted`가 기준이고, 방 상태는 App이 조립할 때 넘긴다.

**경로가 종류를 가른다** — 사진에 붙는 채팅(`COMMENT`·`EMOJI`)은 `POST /api/v1/chats/reaction`,
방 채팅(`DEFAULT`)은 `POST /api/v1/chats`다. 같은 본문을 `/chats`로 보내면 사진이 묶이지 않고
`COMMENT`는 500이 돌아온다 (2026-09-06 확인).

## 내부 구성

- `DTO/` — `BaseResponseDTO`(공통 껍데기, `ChatError` 던짐) · `SendChatRequestDTO` · `ChatMessageDTO`(목록·응답 공통) · `ListChatsResponseDTO` · `SendChatEnvelopeDTO`
- `Endpoint/ChatEndpoint` — `.send` · `.list` (bearer). PhotoData 내부 `ChatEndpoint`(리액션)와 이름이 같지만 다른 모듈·internal
- `Mapping/` — `ChatMessage+Mapping`(+ `ServerDate` UTC 파서 복사본, #51 이후 공용화) · `ChatError+Mapping`(NetworkError→도메인)

## 의존성

- **이 모듈이 의존**: `ChatDomain` · `CHALLANetwork`
- **이 모듈에 의존**: `CHALLAApp`(조립 지점에서만)

## 테스트

- `DefaultChatRepositoryTests` — 목록 경로·쿼리, 사진/텍스트 매핑, 매핑 탈락과 페이지 메타데이터, POST 본문(`{chat:{roomId,photoId,type,content}}`), nil photoID → 0, 오류 정규화(network·401)

## 실시간 수신 (추가)

- `ChatEventSubscriber: ChatEventStreaming` — `/topic/room/{roomId}/chat` 구독.
  프레임 본문을 `ChatMessage`로 바꿔 흘린다. 한 건이 깨져도 건너뛰고 스트림은 유지한다.
- `ChatMessageDTO`가 `chatId`·`userId`를 디코딩한다 (둘 중 하나라도 없으면 그 항목을 버린다).
- `SendChatResponseDTO`가 `chatId`를 읽어 `DefaultChatRepository.send`가 돌려준다.

**미확인**: 소켓 프레임 본문의 실제 형태(봉투 유무)를 아직 캡처하지 못해, 봉투·비봉투 둘 다 받아 준다.
