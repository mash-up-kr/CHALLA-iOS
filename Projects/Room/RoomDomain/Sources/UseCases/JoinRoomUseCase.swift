import Dependencies
import DependenciesMacros

/// 초대 코드로 방에 입장한다. 홈의 두 진입점(빈 상태 버튼, + 메뉴)이 같이 쓴다.
///
/// 형식 검사는 없다 — 형식이 미확정이라 틀린 코드는 저장소가 알려준다.
@DependencyClient
public struct JoinRoomUseCase: Sendable {
    public var run: @Sendable (_ inviteCode: String) async throws -> RoomCard
}

extension JoinRoomUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> JoinRoomUseCase {
        JoinRoomUseCase(run: { rawCode in
            let code = InviteCodeRule.trimmed(rawCode)
            guard InviteCodeRule.isSubmittable(code) else { throw RoomError.invalidInviteCode }
            return try await repository.joinRoom(inviteCode: code)
        })
    }

    public static let testValue = JoinRoomUseCase()

    public static let previewValue = JoinRoomUseCase(
        run: { _ in RoomCard.previewShooting }
    )
}

public extension DependencyValues {
    var joinRoomUseCase: JoinRoomUseCase {
        get { self[JoinRoomUseCase.self] }
        set { self[JoinRoomUseCase.self] = newValue }
    }
}
