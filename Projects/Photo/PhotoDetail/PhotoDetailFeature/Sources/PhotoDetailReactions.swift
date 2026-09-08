import ComposableArchitecture
import Foundation
import PhotoDomain

// 사진 리액션(조회·생성·삭제) 이펙트.
// 리듀서 본체가 길어져 이 관심사만 떼어 뒀다 — 분기는 `PhotoDetailFeature`가 조립한다.

extension PhotoDetailFeature {

    /// 펼친 사진 한 장의 리액션을 지연 조회한다. 목록엔 리액션이 없어 사진을 펼칠 때만 그 한 장을 받는다 —
    /// 이미 받았거나(`reactionsLoaded`) 받는 중(`reactionsLoading`)이면 건너뛴다(안 본 사진은 요청하지 않음).
    func loadReactions(_ state: inout State, photoID: Photo.ID?) -> Effect<Action> {
        guard
            let photoID,
            state.photos[id: photoID] != nil,
            !state.reactionsLoaded.contains(photoID),
            !state.reactionsLoading.contains(photoID)
        else { return .none }

        state.reactionsLoading.insert(photoID)
        if state.reactionsNeedRefresh.contains(photoID) {
            state.reactionsUpdating.insert(photoID)
        }
        let roomID = state.roomID

        return .run { [fetchPhotoReactionsUseCase] send in
            do {
                let reactions = try await fetchPhotoReactionsUseCase.run(roomID, photoID)
                await send(.reactionsResponse(photoID: photoID, .success(reactions)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.reactionsResponse(photoID: photoID, .failure(failure)))
            }
        }
        .cancellable(id: CancelID.reactions(photoID), cancelInFlight: true)
    }

    func refreshReactions(_ state: inout State, photoID: Photo.ID) -> Effect<Action> {
        state.reactionsLoaded.remove(photoID)
        state.reactionsUpdating.insert(photoID)
        state.reactionsNeedRefresh.insert(photoID)
        return loadReactions(&state, photoID: photoID)
    }

    /// 사용자별로 같은 종류의 중복 등록을 막고, 서버 요청 전에 스티커를 표시한다.
    func setReaction(_ state: inout State, kind: ReactionKind) -> Effect<Action> {
        guard let photo = state.selectedPhoto else { return .none }
        guard !state.reactionsUpdating.contains(photo.id) else { return .none }
        if state.reactionsNeedRefresh.contains(photo.id) {
            return refreshReactions(&state, photoID: photo.id)
        }

        let userID = state.currentUserID
        guard !photo.hasReacted(kind, by: userID) else { return .none }
        let roomID = state.roomID
        let photoID = photo.id
        // 서버 응답과 재조회 후에도 표시 ID를 유지한다.
        let reactionID = "local-\(uuid())"
        let burstID = uuid()
        let reaction = PhotoReaction(id: reactionID, kind: kind, userID: userID)

        state.photos[id: photoID] = photo.addingReaction(reaction)
        state.reactionBurst = ReactionBurst(id: burstID, kind: kind)
        state.reactionsUpdating.insert(photoID)
        if state.reactionsLoading.contains(photoID) {
            state.reactionsNeedRefresh.insert(photoID)
        }
        // 초기 조회는 취소하고 변경 완료 후 다시 조회한다.
        state.reactionsLoading.remove(photoID)
        state.reactionsLoaded.insert(photoID)

        return .concatenate(
            .cancel(id: CancelID.reactions(photoID)),
            .run { [setPhotoReactionUseCase] send in
                do {
                    let chatID = try await setPhotoReactionUseCase.run(roomID, photoID, kind)
                    await send(.reactionSucceeded(photoID: photoID, reactionID: reaction.id, chatID: chatID))
                } catch {
                    guard let failure = Self.failure(error) else { return }
                    await send(.reactionFailed(photoID: photoID, reactionID: reaction.id, failure))
                }
            }
        )
    }

    /// 내 스티커면 삭제를 묻고, 남의 스티커면 안내 토스트만 띄운다.
    func stickerTapped(_ state: inout State, reactionID: String) -> Effect<Action> {
        guard let photo = state.selectedPhoto, let reaction = photo.reaction(id: reactionID) else { return .none }
        guard !state.reactionsUpdating.contains(photo.id) else { return .none }
        guard reaction.userID == state.currentUserID else {
            return showToast(&state, Const.othersReactionToast)
        }
        if state.reactionsNeedRefresh.contains(photo.id) {
            return refreshReactions(&state, photoID: photo.id)
        }
        // ID를 받지 못했거나 이전 조회가 실패했다면 다시 조회한다.
        guard reaction.chatID != nil else {
            return .merge(
                showToast(&state, Const.retryLaterToast),
                refreshReactions(&state, photoID: photo.id)
            )
        }

        state.drawer = .deleteReaction(photoID: photo.id, reactionID: reactionID)
        return .none
    }

    /// 삭제를 먼저 표시하고 요청 실패 시 복구한다.
    func deleteReaction(_ state: inout State, photoID: String, reactionID: String) -> Effect<Action> {
        guard
            let photo = state.photos[id: photoID],
            !state.reactionsUpdating.contains(photoID),
            let reaction = photo.reaction(id: reactionID),
            let chatID = reaction.chatID
        else { return .none }

        state.photos[id: photoID] = photo.removingReaction(id: reactionID)
        state.reactionsUpdating.insert(photoID)

        return .run { [deletePhotoReactionUseCase] send in
            do {
                try await deletePhotoReactionUseCase.run(chatID)
                await send(.reactionDeleted(photoID: photoID, restoring: reaction, .success(())))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.reactionDeleted(photoID: photoID, restoring: reaction, .failure(failure)))
            }
        }
    }
}
