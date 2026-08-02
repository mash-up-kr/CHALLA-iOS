import Dependencies
import DependenciesMacros

/// 초대 코드를 정규화해 방에 입장하고 입장한 방을 돌려준다.
/// 홈의 두 진입점(빈 상태 버튼, 상단 + 메뉴)이 같은 이 UseCase를 부른다.
///
/// 코드 형식 검사는 하지 않는다 — 형식이 미확정이라 틀린 코드는 저장소가 알려준다.
@DependencyClient
public struct JoinRoomUseCase: Sendable {
    public var run: @Sendable (_ inviteCode: String) async throws -> Room
}

extension JoinRoomUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> JoinRoomUseCase {
        JoinRoomUseCase(run: { rawCode in
            let code = InviteCodeRule.normalize(rawCode)
            guard InviteCodeRule.isSubmittable(code) else { throw RoomError.invalidInviteCode }
            return try await repository.joinRoom(inviteCode: code)
        })
    }

    public static let testValue = JoinRoomUseCase()

    public static let previewValue = JoinRoomUseCase(
        run: { _ in .previewShooting }
    )
}

public extension DependencyValues {
    var joinRoomUseCase: JoinRoomUseCase {
        get { self[JoinRoomUseCase.self] }
        set { self[JoinRoomUseCase.self] = newValue }
    }
}
