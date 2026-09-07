import CHALLANetwork
import ChatDomain
import Foundation

/// `ChatRepository`의 실서버 구현. 실패는 전부 `ChatError`로 정규화해 던진다.
public struct DefaultChatRepository: ChatRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func messages(inRoom roomID: Int64, page: Int, size: Int) async throws -> [ChatMessage] {
        do {
            let payload = try await client.request(
                ChatEndpoint.list(roomID: roomID, page: page, size: size),
                as: BaseResponseDTO<ListChatsResponseDTO>.self
            ).unwrap()
            // 서버가 메시지 id를 주지 않아 매핑에서 생성한다. 보낸 사람 이름이 없는 항목은 건너뛴다.
            return payload.chats.compactMap { $0.toDomain(id: UUID()) }
        } catch {
            throw ChatError.normalized(error)
        }
    }

    public func send(roomID: Int64, photoID: Int64?, content: String) async throws {
        do {
            // 응답 본문(생성된 chat)은 쓰지 않는다 — 서버가 안정적으로 주지 않아 성공 플래그만 확인한다.
            // `unwrap()`은 data가 nil이면 실패로 던져, 저장은 됐는데 화면엔 에러가 뜨던 문제가 있었다(#71 리액션과 동형).
            let response = try await client.request(
                ChatEndpoint.send(SendChatRequestDTO(roomID: roomID, photoID: photoID, content: content)),
                as: BaseResponseDTO<SendChatResponseDTO>.self
            )
            guard response.success else { throw ChatError.server(message: response.message) }
        } catch {
            throw ChatError.normalized(error)
        }
    }
}
