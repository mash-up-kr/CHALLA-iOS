import CHALLANetwork
import ChatDomain
import Foundation

/// `/topic/room/{roomId}/chat` 구독. STOMP 프레임 본문을 도메인 메시지로 바꿔 흘린다.
public struct ChatEventSubscriber: ChatEventStreaming {

    private let client: any STOMPClienting
    private let decoder = JSONDecoder()

    public init(client: any STOMPClienting) {
        self.client = client
    }

    public func chatEvents(roomID: Int64) async throws -> AsyncThrowingStream<ChatStreamEvent, any Error> {
        // 구독이 확정된 뒤에 리턴한다 — 호출부의 REST 조회는 이 다음에 시작된다.
        let events = try await client.subscribe(to: ChatDestination.chat(roomID: roomID))

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in events {
                        switch event {
                        case let .message(body):
                            // 한 건이 깨져도 스트림을 죽이지 않는다 — 실시간이 통째로 멎는다.
                            guard let message = decode(body) else { continue }
                            continuation.yield(.message(message))
                        case .resumed:
                            continuation.yield(.resumed)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // 소비가 끝나면 위쪽 STOMP 구독까지 연쇄로 해제된다.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 서버가 REST와 같은 봉투로 보내는 것을 기본으로 두되, 봉투 없이 오는 형태도 받아 준다.
    /// (실서버 프레임을 아직 캡처하지 못해 형태를 하나로 못 박지 않는다.)
    func decode(_ body: Data) -> ChatMessage? {
        if
            let envelope = try? decoder.decode(BaseResponseDTO<ChatEventPayloadDTO>.self, from: body),
            let chat = envelope.data?.chat {
            return chat.toDomain()
        }
        if let payload = try? decoder.decode(ChatEventPayloadDTO.self, from: body) {
            return payload.chat.toDomain()
        }
        return (try? decoder.decode(ChatMessageDTO.self, from: body))?.toDomain()
    }
}

/// 서버가 정한 구독 주소.
enum ChatDestination {
    static func chat(roomID: Int64) -> String {
        "/topic/room/\(roomID)/chat"
    }
}
