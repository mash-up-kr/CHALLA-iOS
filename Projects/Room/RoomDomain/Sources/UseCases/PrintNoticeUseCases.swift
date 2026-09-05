import Dependencies
import DependenciesMacros

// 인화 완료 안내가 쓰는 UseCase 2종.
// 묻는 쪽과 기록하는 쪽이 나뉘어 있다 — 부르는 시점이 다르기 때문이다.

// MARK: - 안내를 띄워야 하는지

/// 이 방의 인화 완료 안내를 아직 안 봤는지 묻는다. true면 안내를 띄운다.
@DependencyClient
public struct ShouldShowPrintNoticeUseCase: Sendable {
    /// 확인이 안 되면 안 띄운다. 반복해서 띄우는 쪽이 더 거슬린다.
    public var run: @Sendable (_ roomID: Room.ID) async -> Bool = { _ in false }
}

extension ShouldShowPrintNoticeUseCase: TestDependencyKey {

    public static func live(repository: any PrintNoticeRepository) -> ShouldShowPrintNoticeUseCase {
        ShouldShowPrintNoticeUseCase(run: { roomID in
            await !repository.hasSeenPrintNotice(roomID: roomID)
        })
    }

    public static let testValue = ShouldShowPrintNoticeUseCase()

    public static let previewValue = ShouldShowPrintNoticeUseCase(run: { _ in true })
}

public extension DependencyValues {
    var shouldShowPrintNoticeUseCase: ShouldShowPrintNoticeUseCase {
        get { self[ShouldShowPrintNoticeUseCase.self] }
        set { self[ShouldShowPrintNoticeUseCase.self] = newValue }
    }
}

// MARK: - 봤다고 기록

/// 이 방의 안내를 본 것으로 기록한다 — 다음 진입부터는 뜨지 않는다.
@DependencyClient
public struct MarkPrintNoticeSeenUseCase: Sendable {
    public var run: @Sendable (_ roomID: Room.ID) async -> Void
}

extension MarkPrintNoticeSeenUseCase: TestDependencyKey {

    public static func live(repository: any PrintNoticeRepository) -> MarkPrintNoticeSeenUseCase {
        MarkPrintNoticeSeenUseCase(run: { roomID in
            await repository.markPrintNoticeSeen(roomID: roomID)
        })
    }

    public static let testValue = MarkPrintNoticeSeenUseCase()

    public static let previewValue = MarkPrintNoticeSeenUseCase(run: { _ in })
}

public extension DependencyValues {
    var markPrintNoticeSeenUseCase: MarkPrintNoticeSeenUseCase {
        get { self[MarkPrintNoticeSeenUseCase.self] }
        set { self[MarkPrintNoticeSeenUseCase.self] = newValue }
    }
}
