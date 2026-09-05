import ComposableArchitecture
import Foundation

/// 링크로 받은 초대 코드를 홈에 도달할 때까지 들고 있는 보관함.
///
/// 링크가 로그인 전(스플래시·로그인·프로필 설정)에 도착하면 아직 입장할 수 없어서, 여기 넣어
/// 뒀다가 홈으로 전환하는 순간 꺼내 쓴다. State에 두지 않은 이유는 `AppFeature.State`가
/// 화면 enum이라 화면과 무관한 값을 얹을 자리가 없어서다.
@DependencyClient
struct PendingInviteCode: Sendable {
    /// 코드를 보관한다. 새 코드가 오면 이전 것을 덮는다 — 마지막에 누른 링크가 이긴다.
    var store: @Sendable (String) -> Void
    /// 보관된 코드를 꺼내고 비운다 — 한 번만 나와서 같은 코드로 두 번 입장하지 않는다.
    var take: @Sendable () -> String? = { nil }
}

extension PendingInviteCode: DependencyKey {

    static let liveValue: PendingInviteCode = {
        let box = LockIsolated<String?>(nil)
        return PendingInviteCode(
            store: { code in box.setValue(code) },
            take: { box.withValue { code in
                defer { code = nil }
                return code
            } }
        )
    }()

    /// 테스트 기본값은 "보관된 링크 없음" — 홈에 도달하는 모든 테스트가 take를 지나가므로
    /// 미구현으로 두면 링크와 무관한 테스트까지 실패한다. 보관·전달 검증은 실동작을 직접 주입한다.
    static let testValue = PendingInviteCode(store: { _ in }, take: { nil })
}

extension DependencyValues {
    var pendingInviteCode: PendingInviteCode {
        get { self[PendingInviteCode.self] }
        set { self[PendingInviteCode.self] = newValue }
    }
}
