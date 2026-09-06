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
            // 사진 메시지는 일반 채팅 API가 아닌 리액션 API로 전송한다.
            let request = SendChatRequestDTO(roomID: roomID, photoID: photoID, content: content)
            let endpoint: ChatEndpoint = photoID == nil ? .send(request) : .sendToPhoto(request)

            let response = try await client.request(
                endpoint,
                as: BaseResponseDTO<SendChatResponseDTO>.self
            )
            // 성공 응답도 data가 없을 수 있어 success로 판정한다.
            guard response.success else { throw ChatError.server(message: response.message) }
        } catch {
            throw ChatError.normalized(error)
        }
    }
}
