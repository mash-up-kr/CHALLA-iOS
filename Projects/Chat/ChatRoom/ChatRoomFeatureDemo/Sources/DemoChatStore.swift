import ChatDomain
import Foundation

/// 보낸 메시지를 쌓아 두는 메모리 저장소(서버가 없으니 전송분이 목록에 남게 한다).
actor DemoChatStore {

    private var messages: [ChatMessage]

    init(messages: [ChatMessage]) {
        self.messages = messages
    }

    func all() -> [ChatMessage] {
        messages
    }

    func append(_ message: ChatMessage) {
        messages.append(message)
    }
}
