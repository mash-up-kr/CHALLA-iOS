import Dependencies
import Foundation
import NotificationDomain

/// '서비스 알림' 토글에 맞춰 이 기기의 FCM 토큰을 서버에 등록하거나 해제한다.
///
/// FCM이 토큰을 새로 발급하거나 갱신하면 `AppDelegate`가 `tokenReceived(_:)`로 넘겨주고,
/// 사용자가 설정에서 토글을 바꾸면 `sync()`가 불린다. 두 경로가 언제 들어올지 정해져 있지 않아서
/// 마지막 값을 actor에 들고 있다가, 토글이 켜져 있고 토큰도 있을 때만 서버에 등록한다.
actor PushTokenSynchronizer {

    private let repository: any PushTokenRepository
    private let isServiceNotificationEnabled: @Sendable () async -> Bool
    /// FCM에 발급된 토큰을 직접 물어본다. 델리게이트 콜백이 아직 오지 않았어도 토큰을 지울 수 있어야 한다.
    private let currentToken: @Sendable () async -> String?

    private var token: String?
    /// 이번 실행에서 등록에 성공한 토큰. 같은 값을 두 번 보내지 않으려고 들고 있다.
    ///
    /// 메모리에만 두므로 앱을 다시 켜면 비어 있고, 그래서 실행할 때마다 등록을 한 번 보낸다.
    /// 재설치나 토큰 갱신으로 값이 바뀌었을 수 있어 매번 맞춰 보는 편이 안전하다.
    private var registeredToken: String?

    /// 마지막으로 시작한 작업. 다음 호출이 이게 끝날 때까지 기다린다.
    private var pending: Task<Void, Never>?

    init(
        repository: any PushTokenRepository,
        isServiceNotificationEnabled: @escaping @Sendable () async -> Bool,
        currentToken: @escaping @Sendable () async -> String?
    ) {
        self.repository = repository
        self.isServiceNotificationEnabled = isServiceNotificationEnabled
        self.currentToken = currentToken
    }

    /// FCM이 토큰을 새로 발급하거나 갱신했을 때 `AppDelegate`가 부른다.
    func tokenReceived(_ token: String) async {
        self.token = token
        await sync()
    }

    /// 저장된 토글 값을 읽어 서버의 토큰 등록 상태를 맞춘다.
    /// 앱을 켤 때와 토글을 바꾼 뒤에 부르며, 지난 실행에서 실패한 등록·해제도 여기서 복구된다.
    ///
    /// 바뀐 값을 인자로 받지 않는 이유는 토글을 빠르게 연타하면 호출 순서가 뒤집힐 수 있어서다.
    /// 매번 저장된 값을 다시 읽으면 순서와 상관없이 마지막 값으로 맞춰진다.
    func sync() async {
        await enqueue(.sync)
    }

    /// 로그아웃·탈퇴 때 부른다. 세션이 끊기면 해제 API를 부를 수 없어서 그 전에 지워야 하고,
    /// 토큰 값 자체는 남겨 두어 나중에 다른 계정으로 다시 등록할 수 있게 한다.
    func clear() async {
        await enqueue(.unregister)
    }

    // MARK: - 순차 실행

    private enum Operation: Sendable {
        case sync
        case unregister
    }

    /// 직전 작업이 끝난 뒤에 실행한다.
    ///
    /// actor라도 `await`에서 다른 호출이 들어오므로, 토글을 켰다 바로 끄면 등록과 해제가 함께 돈다.
    /// 서버에 도착하는 순서가 뒤집히면 토글은 꺼졌는데 토큰은 등록된 상태로 남는다.
    private func enqueue(_ operation: Operation) async {
        let previous = pending
        let task = Task {
            await previous?.value
            switch operation {
            case .sync:
                await self.performSync()
            case .unregister:
                await self.unregisterIfNeeded()
            }
        }
        pending = task
        await task.value
    }

    // MARK: - Private

    /// 토글 값은 직전 작업이 끝난 뒤에 읽는다. 기다리는 동안 값이 바뀔 수 있다.
    private func performSync() async {
        if await isServiceNotificationEnabled() {
            await registerIfNeeded()
        } else {
            await unregisterIfNeeded()
        }
    }

    /// 실패해도 사용자에게 알리지 않는다. 화면 없이 도는 동작이라 다음 앱 실행에서 다시 시도한다.
    private func registerIfNeeded() async {
        guard let token = await resolvedToken(), token != registeredToken else { return }
        do {
            try await repository.register(token: token)
            registeredToken = token
        } catch {
            // 이전 값을 그대로 둔다. 여기서 비우면 나중에 해제할 때 방금 실패한 토큰을 지우려 하고,
            // 정작 서버에 등록돼 있던 이전 토큰은 남는다.
        }
    }

    /// 이번 실행에서 등록한 적이 없어도 지난 실행에서 등록해 둔 토큰이 남아 있을 수 있어서,
    /// 기억해 둔 값이 없으면 FCM에 직접 물어보고 그 토큰을 해제한다.
    private func unregisterIfNeeded() async {
        // `??`는 오른쪽이 autoclosure라 await를 넣을 수 없다.
        let target: String? = if let registeredToken {
            registeredToken
        } else {
            await resolvedToken()
        }
        guard let target else { return }
        try? await repository.unregister(token: target)
        // 실패해도 등록이 풀린 것으로 본다. 남겨두면 토글을 다시 켤 때 같은 값이라 등록을 건너뛴다.
        registeredToken = nil
    }

    private func resolvedToken() async -> String? {
        if let token {
            return token
        }
        token = await currentToken()
        return token
    }
}

// MARK: - Dependency

/// `AppDelegate`가 FCM 콜백에서 꺼내 쓴다. 실제 인스턴스는 `CompositionRoot`가 넣는다.
private enum PushTokenSynchronizerKey: DependencyKey {
    /// 조립 전에 접근했을 때 쓰는 안전값. 앱이 죽는 것보다 푸시가 안 오는 편이 낫다.
    static let liveValue = PushTokenSynchronizer(
        repository: NoopPushTokenRepository(),
        isServiceNotificationEnabled: { false },
        currentToken: { nil }
    )
}

extension DependencyValues {
    var pushTokenSynchronizer: PushTokenSynchronizer {
        get { self[PushTokenSynchronizerKey.self] }
        set { self[PushTokenSynchronizerKey.self] = newValue }
    }
}

private struct NoopPushTokenRepository: PushTokenRepository {
    func register(token _: String) async throws {}
    func unregister(token _: String) async throws {}
    #if DEBUG
        func sendTestPush(title _: String, body _: String) async throws -> Int {
            0
        }
    #endif
}
