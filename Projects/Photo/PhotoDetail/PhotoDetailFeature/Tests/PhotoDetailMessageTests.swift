import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 메시지 전송")
struct PhotoDetailMessageTests {

    @Test("메시지를 보내면 입력창을 비우고 보냈다고 알린다")
    func showsToastAfterSending() async {
        let target = Fixture.photo(id: "1") // 전송은 사진 id를 Int64로 바꿔 보낸다
        let store = await openedTestStore(photos: [target], sendChat: { roomID, photoID, content in
            #expect(roomID == Fixture.roomID)
            #expect(photoID == 1)
            #expect(content == "좋다")
        })

        await store.send(.view(.messageChanged("좋다"))) { $0.messageDraft = "좋다" }
        await store.send(.view(.sendMessageTapped)) {
            $0.isSendingMessage = true
            $0.messageDraft = ""
        }
        // `\.messageSent.success`로 좁히면 Result<Void, _> 케이스 키패스에서 컴파일러가 죽는다(Swift 6.3.3).
        await store.receive(\.messageSent) {
            $0.isSendingMessage = false
            $0.toast = "메시지를 보냈어요"
        }
        await store.receive(\.toastDismissed) { $0.toast = nil }
    }
}
