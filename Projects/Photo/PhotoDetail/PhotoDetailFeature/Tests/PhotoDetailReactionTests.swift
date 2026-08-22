import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain
import Testing

@MainActor
@Suite("PhotoDetailFeature — 리액션")
struct PhotoDetailReactionTests {

    @Test("첫 이모지는 스티커·띠에 붙고, 이모지 애니메이션이 튄다")
    func firstReactionAddsStickerAndBurst() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], setReaction: { roomID, photoID, kind, isOn in
            #expect(roomID == Fixture.roomID)
            #expect(photoID == "photo-1")
            #expect(kind == .thumbsUp)
            #expect(isOn)
        })

        await store.send(.view(.reactionTapped(.thumbsUp))) {
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(0), kind: .thumbsUp)
            $0.photos[id: "photo-1"] = target.addingReaction(.thumbsUp, by: Fixture.currentUserID)
        }
        await store.receive(\.reactionSucceeded)
    }

    @Test("두 번째 이모지는 스티커는 그대로, 띠에는 쌓이고 애니메이션이 튄다")
    func secondKindUpdatesBandKeepsSticker() async {
        let target = Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.heart, by: Fixture.currentUserID)])
        let store = await openedTestStore(photos: [target], setReaction: { _, _, kind, _ in
            #expect(kind == .thumbsUp)
        })

        await store.send(.view(.reactionTapped(.thumbsUp))) {
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(0), kind: .thumbsUp)
            // 스티커는 heart 유지, 띠는 {heart, thumbsUp}
            $0.photos[id: "photo-1"] = target.addingReaction(.thumbsUp, by: Fixture.currentUserID)
        }
        await store.receive(\.reactionSucceeded)
    }

    @Test("이미 그 종류로 남긴 이모지를 다시 누르면 아무 것도 하지 않는다")
    func ignoresAlreadyReactedKind() async {
        let target = Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.heart, by: Fixture.currentUserID)])
        // 기본 setReaction은 호출되면 던지지만, 여기선 아예 호출되지 않아야 한다.
        let store = await openedTestStore(photos: [target])

        await store.send(.view(.reactionTapped(.heart)))
    }

    @Test("전송 실패 시 방금 누른 그 종류만 되돌리고 얼럿을 띄운다")
    func rollsBackFailedKind() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _, _ in
            throw PhotoError.network
        })

        await store.send(.view(.reactionTapped(.heart))) {
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(0), kind: .heart)
            $0.photos[id: "photo-1"] = target.addingReaction(.heart, by: Fixture.currentUserID)
        }
        await store.receive(\.reactionFailed) {
            $0.photos[id: "photo-1"] = target // heart 제거 → 원래대로
            $0.alert = AlertState {
                TextState("리액션을 남기지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }

    @Test("두 번째 종류 전송이 실패하면 스티커는 유지되고 그 종류만 띠에서 빠진다")
    func failureOnSecondKindKeepsSticker() async {
        let target = Fixture.photo(id: "photo-1", reactions: [Fixture.reaction(.heart, by: Fixture.currentUserID)])
        let store = await openedTestStore(photos: [target], setReaction: { _, _, _, _ in
            throw PhotoError.network
        })

        await store.send(.view(.reactionTapped(.thumbsUp))) {
            $0.reactionBurst = PhotoDetailFeature.ReactionBurst(id: UUID(0), kind: .thumbsUp)
            $0.photos[id: "photo-1"] = target.addingReaction(.thumbsUp, by: Fixture.currentUserID)
        }
        await store.receive(\.reactionFailed) {
            $0.photos[id: "photo-1"] = target // thumbsUp만 빠지고 heart 스티커·띠 유지
            $0.alert = AlertState {
                TextState("리액션을 남기지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.network.userMessage)
            }
        }
    }

    @Test("펼친 사진이 없으면 리액션 탭은 아무 일도 하지 않는다")
    func ignoresReactionWithoutPhoto() async {
        let store = makeTestStore()

        await store.send(.view(.reactionTapped(.thumbsUp)))
    }
}
