import Dependencies
import DependenciesMacros
import Foundation

/// 이름 규칙을 적용해 방 이름을 바꾼다. 적용된(정제된) 이름을 돌려준다 —
/// 뷰가 입력값 대신 이 값으로 화면을 갱신해야 서버에 저장된 이름과 어긋나지 않는다.
///
/// 방 만들기와 같은 규칙(`RoomNameRule`)을 쓴다 — 진입점이 달라도 이름 규칙은 하나다.
@DependencyClient
public struct UpdateRoomTitleUseCase: Sendable {
    public var run: @Sendable (_ roomID: Room.ID, _ title: String) async throws -> String
}

extension UpdateRoomTitleUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> UpdateRoomTitleUseCase {
        UpdateRoomTitleUseCase(run: { roomID, title in
            // 공백을 먼저 뗀다 — 자르기가 먼저면 "공백 20자 + 여행"이 공백만 남는다 (CreateRoomUseCase와 동일).
            let name = RoomNameRule.truncated(RoomNameRule.trimmed(title))
            guard RoomNameRule.isSubmittable(name) else { throw RoomError.invalidRoomName }
            try await repository.updateTitle(roomID: roomID, title: name)
            return name
        })
    }

    public static let testValue = UpdateRoomTitleUseCase()

    /// 입력한 이름을 그대로 돌려준다 (프리뷰 확인용).
    public static let previewValue = UpdateRoomTitleUseCase(run: { _, title in title })
}

public extension DependencyValues {
    var updateRoomTitleUseCase: UpdateRoomTitleUseCase {
        get { self[UpdateRoomTitleUseCase.self] }
        set { self[UpdateRoomTitleUseCase.self] = newValue }
    }
}
