import Dependencies
import DependenciesMacros
import Foundation

/// 인화 완료 확인을 서버에 기록한다 — 확인하기를 눌러 방에 들어가는 시점에 부른다.
/// 규칙 없는 단순 통과지만 Feature는 UseCase만 보는 관례를 유지한다.
@DependencyClient
public struct CheckPrintCompletionUseCase: Sendable {
    public var run: @Sendable (_ roomID: Room.ID) async throws -> Void
}

extension CheckPrintCompletionUseCase: TestDependencyKey {

    public static func live(repository: any RoomRepository) -> CheckPrintCompletionUseCase {
        CheckPrintCompletionUseCase(run: { roomID in
            try await repository.checkPrintCompletion(roomID: roomID)
        })
    }

    public static let testValue = CheckPrintCompletionUseCase()

    /// 프리뷰는 기록할 서버가 없어 아무것도 하지 않는다.
    public static let previewValue = CheckPrintCompletionUseCase(run: { _ in })
}

public extension DependencyValues {
    var checkPrintCompletionUseCase: CheckPrintCompletionUseCase {
        get { self[CheckPrintCompletionUseCase.self] }
        set { self[CheckPrintCompletionUseCase.self] = newValue }
    }
}
