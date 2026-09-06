import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 이모지 삭제")
struct PhotoDetailReactionDeleteTests {

    @Test("삭제 요청과 후속 조회 중에는 추가 생성과 삭제를 막는다")
    func serializesDeletionAndRefresh() async {
        let clock = TestClock()
        let requests = LockIsolated(0)
        let first = Fixture.reaction(.heart, by: Fixture.currentUserID, chatID: 1)
        let second = Fixture.reaction(.fire, by: Fixture.currentUserID, chatID: 2)
        let target = Fixture.photo(id: "photo-1", reactions: [first, second])
        let remaining = target.removingReaction(id: first.id)
        let store = await openedTestStore(
            photos: [target],
            reactions: { _, _ in
                let request = requests.withValue { $0 += 1; return $0 }
                if request > 1 {
                    try await clock.sleep(for: .seconds(1))
                }
                let photo = request == 1 ? target : remaining
                return PhotoReactions(stickers: photo.reactions, reactedKindsByUser: photo.reactedKindsByUser)
            },
            setReaction: { _, _, _ in 3 },
            deleteReaction: { _ in try await clock.sleep(for: .seconds(1)) }
        )
        store.exhaustivity = .off

        await store.send(.view(.stickerTapped(reactionID: first.id)))
        await store.send(.view(.deleteReactionConfirmed))
        await store.send(.view(.reactionTapped(.heart)))
        await store.send(.view(.stickerTapped(reactionID: second.id)))
        #expect(store.state.drawer == nil)
        #expect(store.state.selectedPhoto == remaining)

        await clock.advance(by: .seconds(1))
        await store.receive(\.reactionDeleted)
        await store.send(.view(.reactionTapped(.heart)))
        #expect(store.state.selectedPhoto == remaining)
        #expect(store.state.reactionsUpdating.contains("photo-1"))

        await clock.advance(by: .seconds(1))
        await store.receive(\.reactionsResponse)
        #expect(store.state.reactionsUpdating.isEmpty)
        await store.send(.view(.reactionTapped(.heart)))
        await store.receive(\.reactionSucceeded)
        #expect(store.state.selectedPhoto?.reactions.map(\.chatID) == [2, 3])
    }

    private static let myReaction = Fixture.reaction(.heart, by: Fixture.currentUserID, chatID: Fixture.chatID)

    /// 내가 남긴 스티커 하나가 붙어 있는 사진.
    private func photoWithMySticker() -> Photo {
        Fixture.photo(id: "photo-1", reactions: [Self.myReaction])
    }

    private var deleteDrawer: PhotoDetailFeature.Drawer {
        .deleteReaction(photoID: "photo-1", reactionID: Self.myReaction.id)
    }

    @Test("내 스티커를 탭하면 삭제할지 드로어로 묻는다")
    func asksBeforeDeletingMySticker() async {
        let store = await openedTestStore(photos: [photoWithMySticker()])

        await store.send(.view(.stickerTapped(reactionID: Self.myReaction.id))) {
            $0.drawer = self.deleteDrawer
        }
    }

    @Test("삭제를 확정하면 스티커를 떼고 서버 값으로 다시 맞춘다")
    func deletesMySticker() async {
        let target = photoWithMySticker()
        let isDeleted = LockIsolated(false)
        let store = await openedTestStore(photos: [target], reactions: { _, _ in
            isDeleted.value ? PhotoReactions() : PhotoReactions(
                stickers: target.reactions, reactedKindsByUser: target.reactedKindsByUser
            )
        }, deleteReaction: { chatID in
            #expect(chatID == Fixture.chatID)
            isDeleted.setValue(true)
        })

        await store.send(.view(.stickerTapped(reactionID: Self.myReaction.id))) {
            $0.drawer = self.deleteDrawer
        }
        await store.send(.view(.deleteReactionConfirmed)) {
            $0.reactionsUpdating.insert("photo-1")
            $0.drawer = nil
            $0.photos[id: "photo-1"] = target.removingReaction(id: Self.myReaction.id)
        }
        await store.receive(\.reactionDeleted) {
            $0.reactionsNeedRefresh.insert("photo-1")
            $0.reactionsLoaded.remove("photo-1")
            $0.reactionsLoading.insert("photo-1")
        }
        await store.receive(\.reactionsResponse) {
            $0.reactionsUpdating.remove("photo-1")
            $0.reactionsNeedRefresh.remove("photo-1")
            $0.reactionsLoading.remove("photo-1")
            $0.reactionsLoaded.insert("photo-1")
            $0.photos[id: "photo-1"] = target.removingReaction(id: Self.myReaction.id)
        }
    }

    @Test("삭제에 실패하면 스티커를 그대로 되돌리고 얼럿을 띄운다")
    func restoresStickerWhenDeleteFails() async {
        let target = photoWithMySticker()
        let store = await openedTestStore(photos: [target], deleteReaction: { _ in
            throw PhotoError.network
        })

        await store.send(.view(.stickerTapped(reactionID: Self.myReaction.id))) {
            $0.drawer = self.deleteDrawer
        }
        await store.send(.view(.deleteReactionConfirmed)) {
            $0.reactionsUpdating.insert("photo-1")
            $0.drawer = nil
            $0.photos[id: "photo-1"] = target.removingReaction(id: Self.myReaction.id)
        }
        await store.receive(\.reactionDeleted) {
            $0.reactionsUpdating.remove("photo-1")
            $0.photos[id: "photo-1"] = target
            $0.alert = AlertState {
                TextState("이모지를 삭제하지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }

    @Test("채팅 ID가 없는 스티커를 누르면 안내 후 재조회한다")
    func showsNoticeWhenChatIDMissing() async {
        // 서버 응답 전(낙관적으로 붙인 직후) 상태의 스티커.
        let pending = PhotoReaction(id: "local-1", kind: .heart, userID: Fixture.currentUserID)
        let store = await openedTestStore(photos: [Fixture.photo(id: "photo-1", reactions: [pending])])

        await store.send(.view(.stickerTapped(reactionID: pending.id))) {
            $0.toast = "잠시 후 다시 시도해 주세요"
            $0.reactionsLoaded.remove("photo-1")
            $0.reactionsLoading.insert("photo-1")
            $0.reactionsUpdating.insert("photo-1")
            $0.reactionsNeedRefresh.insert("photo-1")
        }
        store.exhaustivity = .off
        await store.finish()
        await store.skipReceivedActions(strict: false)
        #expect(store.state.toast == nil)
        #expect(store.state.reactionsUpdating.isEmpty)
    }

    @Test("남의 스티커를 탭하면 삭제하지 않고 안내만 한다")
    func showsNoticeForOthersSticker() async {
        let others = Fixture.reaction(.fire, by: "user-other", chatID: 99)
        let store = await openedTestStore(photos: [Fixture.photo(id: "photo-1", reactions: [others])])

        await store.send(.view(.stickerTapped(reactionID: others.id))) {
            $0.toast = "내가 남긴 이모지만 지울 수 있어요"
        }
        await store.receive(\.toastDismissed) { $0.toast = nil }
    }
}
