import Dependencies
import DependenciesMacros

// 초대 안내(첫 방 상세 진입 시 팝오버 + 툴팁)가 쓰는 UseCase 2종.
// 읽기(띄울까)와 쓰기(봤다고 기록)는 부르는 시점이 다르다 — 진입 시 / 팝오버 닫을 때.
// 타입을 나누면 확인만 하는 자리에 기록 권한이 함께 넘어가지 않는다.
//
// `liveValue`는 없다 — 채우려면 여기서 구체 저장소를 만들어 Domain이 Data를 보게 된다.
// `.live(repository:)`가 인터페이스만 받아 조립하고, 구체 저장소는 합성 루트가 넘긴다.

// MARK: - 안내를 봐야 하는지

/// 방 상세에 처음 들어왔는지 묻는다. true면 초대 코드 팝오버를 열고 툴팁을 띄운다.
@DependencyClient
public struct ShouldShowInviteGuideUseCase: Sendable {
    /// 기기 저장값을 읽을 뿐이라 실패 개념이 없다 — 던지지 않는다.
    /// 기본값은 false — 확인이 안 되는 상황에서 안내를 반복해 띄우지 않는다.
    public var run: @Sendable () async -> Bool = { false }
}

extension ShouldShowInviteGuideUseCase: TestDependencyKey {

    public static func live(repository: any InviteGuideRepository) -> ShouldShowInviteGuideUseCase {
        ShouldShowInviteGuideUseCase(run: { await !repository.hasSeenInviteGuide() })
    }

    public static let testValue = ShouldShowInviteGuideUseCase()

    public static let previewValue = ShouldShowInviteGuideUseCase(run: { true })
}

public extension DependencyValues {
    var shouldShowInviteGuideUseCase: ShouldShowInviteGuideUseCase {
        get { self[ShouldShowInviteGuideUseCase.self] }
        set { self[ShouldShowInviteGuideUseCase.self] = newValue }
    }
}

// MARK: - 봤다고 기록

/// 안내를 본 것으로 기록한다 — 다음 진입부터는 뜨지 않는다.
@DependencyClient
public struct MarkInviteGuideSeenUseCase: Sendable {
    public var run: @Sendable () async -> Void
}

extension MarkInviteGuideSeenUseCase: TestDependencyKey {

    public static func live(repository: any InviteGuideRepository) -> MarkInviteGuideSeenUseCase {
        MarkInviteGuideSeenUseCase(run: { await repository.markInviteGuideSeen() })
    }

    public static let testValue = MarkInviteGuideSeenUseCase()

    public static let previewValue = MarkInviteGuideSeenUseCase(run: {})
}

public extension DependencyValues {
    var markInviteGuideSeenUseCase: MarkInviteGuideSeenUseCase {
        get { self[MarkInviteGuideSeenUseCase.self] }
        set { self[MarkInviteGuideSeenUseCase.self] = newValue }
    }
}
