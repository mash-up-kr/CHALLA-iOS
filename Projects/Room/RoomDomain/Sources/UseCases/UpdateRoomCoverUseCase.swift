import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct UpdateRoomCoverUseCase: Sendable {
    public var run: @Sendable (_ roomID: Room.ID, _ draft: RoomCoverDraft) async throws -> Void
}

extension UpdateRoomCoverUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> UpdateRoomCoverUseCase {
        UpdateRoomCoverUseCase(run: { roomID, draft in
            try await repository.updateCover(
                roomID: roomID,
                imageURL: draft.imageURL,
                stickerID: draft.stickerID,
                // 스티커 없이 색만 실을 자리가 서버에 없다 — 화면이 색을 기억하는 것과 별개다.
                colorID: draft.stickerID == nil ? nil : draft.colorID
            )
        })
    }

    public static let testValue = UpdateRoomCoverUseCase()

    public static let previewValue = UpdateRoomCoverUseCase(run: { _, _ in })
}

public extension DependencyValues {
    var updateRoomCoverUseCase: UpdateRoomCoverUseCase {
        get { self[UpdateRoomCoverUseCase.self] }
        set { self[UpdateRoomCoverUseCase.self] = newValue }
    }
}
