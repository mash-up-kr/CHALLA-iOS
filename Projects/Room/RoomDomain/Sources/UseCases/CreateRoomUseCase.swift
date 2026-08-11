import Dependencies
import DependenciesMacros
import Foundation

/// 이름 규칙을 적용해 방을 만든다.
///
/// 뷰가 이미 막고 있어도 여기서 한 번 더 본다 — 진입점이 늘어도 규칙이 새지 않는다.
@DependencyClient
public struct CreateRoomUseCase: Sendable {
    public var run: @Sendable (_ draft: RoomDraft) async throws -> RoomCard
}

extension CreateRoomUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> CreateRoomUseCase {
        CreateRoomUseCase(run: { draft in
            // 공백을 먼저 뗀다 — 자르기가 먼저면 "공백 20자 + 여행"이 공백만 남는다.
            let name = RoomNameRule.truncated(RoomNameRule.trimmed(draft.name))
            guard RoomNameRule.isSubmittable(name) else { throw RoomError.invalidRoomName }
            return try await repository.createRoom(
                RoomDraft(name: name, shotCount: draft.shotCount)
            )
        })
    }

    public static let testValue = CreateRoomUseCase()

    /// 입력한 이름을 그대로 돌려준다 (프리뷰 확인용).
    public static let previewValue = CreateRoomUseCase(
        run: { draft in
            RoomCard(
                room: Room(
                    id: -100,
                    title: draft.name,
                    status: .shooting,
                    totalPhotoCount: draft.shotCount.rawValue,
                    remainedPhotoCount: draft.shotCount.rawValue, // 방금 만들어 아직 안 찍었다
                    createdAt: .now,
                    expiresAt: .now.addingTimeInterval(60 * 60 * 24 * 30)
                ),
                memberCount: 1, // 만든 직후라 혼자다
                thumbnailURLs: []
            )
        }
    )
}

public extension DependencyValues {
    var createRoomUseCase: CreateRoomUseCase {
        get { self[CreateRoomUseCase.self] }
        set { self[CreateRoomUseCase.self] = newValue }
    }
}
