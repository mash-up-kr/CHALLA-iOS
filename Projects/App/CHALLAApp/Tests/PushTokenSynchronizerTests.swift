@testable import CHALLAApp
import Foundation
import NotificationDomain
import Testing

/// 호출 순서를 기록하고, 등록·해제가 동시에 돌고 있는지 센다.
private actor MockPushTokenRepository: PushTokenRepository {

    enum Call: Equatable {
        case register(String)
        case unregister(String)
    }

    private(set) var calls: [Call] = []
    private(set) var maxInFlight = 0
    private var inFlight = 0

    func register(token: String) async throws {
        await record(.register(token))
    }

    func unregister(token: String) async throws {
        await record(.unregister(token))
    }

    #if DEBUG
        func sendTestPush(title _: String, body _: String) async throws -> Int {
            0
        }
    #endif

    /// 서버 왕복을 흉내내려고 중간에 한 번 멈춘다.
    /// 순차 실행이 아니면 이 사이에 다른 호출이 들어와 `inFlight`가 2가 된다.
    private func record(_ call: Call) async {
        calls.append(call)
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        try? await Task.sleep(nanoseconds: 5_000_000)
        inFlight -= 1
    }
}

private actor ToggleBox {

    private(set) var isEnabled: Bool

    init(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func set(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

@Suite("PushTokenSynchronizer — 직렬 실행")
struct PushTokenSynchronizerTests {

    private static let token = "fcm-token"

    private static func makeSynchronizer(
        repository: MockPushTokenRepository,
        toggle: ToggleBox
    ) -> PushTokenSynchronizer {
        PushTokenSynchronizer(
            repository: repository,
            isServiceNotificationEnabled: { await toggle.isEnabled },
            currentToken: { token }
        )
    }

    @Test("동시에 들어와도 등록·해제가 겹치지 않는다")
    func serializesConcurrentCalls() async {
        let repository = MockPushTokenRepository()
        let synchronizer = Self.makeSynchronizer(repository: repository, toggle: ToggleBox(true))

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 8 {
                group.addTask {
                    if index.isMultiple(of: 2) {
                        await synchronizer.sync()
                    } else {
                        await synchronizer.clear()
                    }
                }
            }
        }

        #expect(await repository.maxInFlight == 1)
    }

    @Test("등록이 도는 중에 토글을 끄면 해제가 마지막에 남는다")
    func readsToggleAfterWaitingInLine() async {
        let repository = MockPushTokenRepository()
        let toggle = ToggleBox(true)
        let synchronizer = Self.makeSynchronizer(repository: repository, toggle: toggle)

        // 등록이 실제로 시작된 뒤에 토글을 꺼야 두 작업이 겹친 상황이 된다.
        let registering = Task { await synchronizer.sync() }
        while await repository.calls.isEmpty {
            await Task.yield()
        }

        await toggle.set(false)
        let unregistering = Task { await synchronizer.sync() }

        await registering.value
        await unregistering.value

        #expect(await repository.calls == [.register(Self.token), .unregister(Self.token)])
    }

    @Test("같은 토큰을 두 번 등록하지 않는다")
    func skipsAlreadyRegisteredToken() async {
        let repository = MockPushTokenRepository()
        let synchronizer = Self.makeSynchronizer(repository: repository, toggle: ToggleBox(true))

        await synchronizer.sync()
        await synchronizer.sync()

        #expect(await repository.calls == [.register(Self.token)])
    }

    @Test("토글이 꺼져 있으면 등록하지 않고 해제한다")
    func unregistersWhenToggleIsOff() async {
        let repository = MockPushTokenRepository()
        let synchronizer = Self.makeSynchronizer(repository: repository, toggle: ToggleBox(false))

        await synchronizer.sync()

        #expect(await repository.calls == [.unregister(Self.token)])
    }
}
