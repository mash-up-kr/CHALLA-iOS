import ComposableArchitecture
import Foundation
import RoomDomain

// MARK: - 커버 수정 화면 전이

extension AppFeature {

    /// 설정 → 커버 수정. 설정에서 이름을 바꿨을 수 있어 최신 제목으로 넘긴다 (상세 복귀와 같은 이유).
    func openCoverEdit(_ state: inout State) {
        guard case let .roomSettings(screen) = state else { return }
        state = .roomCoverEdit(
            RoomCoverEditScreen(
                profile: screen.profile,
                room: screen.room.renamed(to: screen.settings.title),
                homeCards: screen.homeCards,
                memberCount: screen.memberCount
            )
        )
    }

    /// 커버 수정 → 설정. 저장에 성공한 커버를 방에 반영해 둔다 — 상세·홈이 재조회 전에도 새 커버를 그린다.
    func closeCoverEdit(_ state: inout State) {
        guard case let .roomCoverEdit(screen) = state else { return }
        state = .roomSettings(
            RoomSettingsScreen(
                profile: screen.profile,
                room: screen.room.withCover(screen.coverEdit.savedCover),
                homeCards: screen.homeCards,
                memberCount: screen.memberCount
            )
        )
    }
}

// MARK: - 커버 백그라운드 저장

extension AppFeature {

    func saveRoomCover(roomID: Room.ID, cover: RoomCover, previous: RoomCover) -> Effect<Action> {
        .run { [updateRoomCoverUseCase] send in
            do {
                try await updateRoomCoverUseCase.run(roomID, RoomCoverDraft(cover: cover))
            } catch {
                await send(.roomCoverSaveFailed(roomID: roomID, previousCover: previous))
            }
        }
    }

    /// 낙관적으로 반영해 둔 커버를 저장 전 값으로 되돌린다. 사용자는 이미 다른 화면이라 알리지 않는다 —
    /// 다음 조회가 서버 값을 다시 준다.
    func revertRoomCover(roomID: Room.ID, to previousCover: RoomCover, _ state: inout State) {
        switch state {
        case var .roomSettings(screen) where screen.room.id == roomID:
            screen.room = screen.room.withCover(previousCover)
            state = .roomSettings(screen)
        case var .roomDetail(screen) where screen.roomDetail.room.id == roomID:
            screen.roomDetail.room = screen.roomDetail.room.withCover(previousCover)
            state = .roomDetail(screen)
        default:
            break
        }
    }
}
