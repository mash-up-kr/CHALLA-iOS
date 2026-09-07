import Foundation

/// 채팅 API 프로토콜. 구현은 `ChatData`가 맡는다.
/// 구현은 실패를 `ChatError`로 바꿔 던져야 한다.
public protocol ChatRepository: Sendable {

    /// 방의 채팅을 최근 페이지부터 받아 온다. 서버 응답에 `hasNext`가 없어 "받은 개수 == size"로 다음 여부를 가늠한다.
    func messages(inRoom roomID: Int64, page: Int, size: Int) async throws -> [ChatMessage]

    /// 메시지를 보낸다. 방 단위 텍스트 메시지는 `photoID`가 nil(붙일 사진 없음), 사진 상세에서 보낼 땐 그 사진 id.
    ///
    /// 성공 여부만 알린다(반환 없음) — 서버가 생성된 채팅 본문을 신뢰성 있게 주지 않아(#71 리액션과 같은 부류),
    /// 화면은 로컬에서 만든 메시지를 낙관적으로 덧붙이고 실패 시 되돌린다.
    func send(roomID: Int64, photoID: Int64?, content: String) async throws
}
