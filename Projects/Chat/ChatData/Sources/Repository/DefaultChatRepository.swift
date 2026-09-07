import CHALLANetwork
import ChatDomain
import Foundation

/// `ChatRepository`의 실서버 구현. 실패는 전부 `ChatError`로 정규화해 던진다.
public struct DefaultChatRepository: ChatRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func messages(inRoom roomID: Int64, page: Int, size: Int) async throws -> ChatPage {
        do {
            let payload = try await client.request(
                ChatEndpoint.list(roomID: roomID, page: page, size: size),
                as: BaseResponseDTO<ListChatsResponseDTO>.self
            ).unwrap()
            // chatId·userId·보낸 사람 이름이 없는 항목은 건너뛴다.
            return ChatPage(
                messages: payload.chats.compactMap { $0.toDomain() },
                nextPage: page + 1,
                // 매핑에서 제외된 항목 때문에 페이지가 일찍 끝난 것으로 오판하지 않는다.
                hasMore: payload.chats.count >= size
            )
        } catch {
            throw ChatError.normalized(error)
        }
    }

    @discardableResult
    public func send(roomID: Int64, photoID: Int64?, content: String) async throws -> Int64? {
        do {
            // 사진 메시지는 일반 채팅 API가 아닌 리액션 API로 전송한다.
            let request = SendChatRequestDTO(roomID: roomID, photoID: photoID, content: content)
            let endpoint: ChatEndpoint = photoID == nil ? .send(request) : .sendToPhoto(request)

            // `unwrap()`을 쓰지 않는다 — data가 nil이면 실패로 던져, 저장은 됐는데 화면엔 에러가 뜨던
            // 문제가 있었다(#71 리액션과 동형). 성공 플래그만 보고, chatId는 있으면 쓴다.
            let response = try await client.request(
                endpoint,
                as: BaseResponseDTO<SendChatResponseDTO>.self
            )
            // 성공 응답도 data가 없을 수 있어 success로 판정한다.
            guard response.success else { throw ChatError.server(message: response.message) }
            return response.data?.chatId
        } catch {
            throw ChatError.normalized(error)
        }
    }
}
