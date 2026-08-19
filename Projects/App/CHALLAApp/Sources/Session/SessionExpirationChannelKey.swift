import AuthDomain
import Dependencies

/// 기본값은 아무것도 흘리지 않는 채널이다 — 실제 채널은 `CompositionRoot`가 갱신 경로와 함께 꽂는다.
private enum SessionExpirationChannelKey: DependencyKey {
    static let liveValue = SessionExpirationChannel()
}

extension DependencyValues {
    var sessionExpirationChannel: SessionExpirationChannel {
        get { self[SessionExpirationChannelKey.self] }
        set { self[SessionExpirationChannelKey.self] = newValue }
    }
}
