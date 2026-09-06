import Foundation

/// 채팅 API 프로토콜. 구현은 `ChatData`가 맡는다.
/// 구현은 실패를 `ChatError`로 바꿔 던져야 한다.
public protocol ChatRepository: Sendable {

    /// 방의 채팅을 최근 페이지부터 받아 온다. 서버 응답에 `hasNext`가 없어 "받은 개수 == size"로 다음 여부를 가늠한다.
    func messages(inRoom roomID: Int64, page: Int, size: Int) async throws -> [ChatMessage]

    /// 메시지를 보낸다. 방 단위 텍스트 메시지는 `photoID`가 nil(붙일 사진 없음), 사진 상세에서 보낼 땐 그 사진 id.
    ///
    /// - Returns: 서버가 만든 `chatId`. 화면은 이 값으로 낙관적 메시지를 확정해,
    ///   소켓으로 같은 메시지가 되돌아와도 목록에 두 번 뜨지 않게 한다.
    ///   서버가 본문을 신뢰성 있게 주지 않던 이력이 있어(#71 리액션과 같은 부류) nil일 수 있고,
    ///   그때는 낙관적 메시지를 로컬 id인 채로 둔다.
    @discardableResult
    func send(roomID: Int64, photoID: Int64?, content: String) async throws -> Int64?
}
