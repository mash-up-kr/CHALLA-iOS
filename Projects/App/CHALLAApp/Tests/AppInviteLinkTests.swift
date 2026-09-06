@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import HomeFeature
import ProfileSetupFeature
import RoomDomain
import Testing
import UserDomain

/// 유니버설 링크(초대 링크) 처리 — 화면 상태별 분기와 콜드 스타트의 보관·전달을 본다.
/// 입장 자체(목록 반영·실패 얼럿)는 `HomeInviteJoinTests`가 본다.
@MainActor
@Suite("AppFeature 초대 링크")
struct AppInviteLinkTests {

    private nonisolated static let profile = UserProfile(id: 1, nickname: "찰나", imageURL: nil)
    private nonisolated static let card = RoomCard.previewShooting

    private nonisolated static func inviteURL() throws -> URL {
        try #require(InviteLink.url(code: "1928121"))
    }

    @Test("초대 링크가 아니면 아무것도 하지 않는다")
    func ignoresForeignURL() async throws {
        let store = TestStore(initialState: AppFeature.State.home(AppFeature.HomeScreen(profile: Self.profile))) {
            AppFeature()
        }

        let url = try #require(URL(string: "https://example.com/invite/1928121"))
        await store.send(.inviteLinkOpened(url))
    }

    @Test("홈에서 링크를 받으면 그 방에 입장해 방 상세로 간다")
    func joinsFromHome() async throws {
        let store = TestStore(initialState: AppFeature.State.home(AppFeature.HomeScreen(profile: Self.profile))) {
            AppFeature()
        } withDependencies: {
            $0.joinRoomUseCase = JoinRoomUseCase(run: { _ in Self.card })
        }
        // 홈 자식까지 도는 통합 흐름이라 결과 화면만 본다 — 중간 액션은 홈 테스트의 몫.
        store.exhaustivity = .off

        try await store.send(.inviteLinkOpened(Self.inviteURL()))
        // 비관용 모드에서 finish()는 큐의 수신 액션을 상태에 적용하지 않는다 —
        // 마지막 액션을 받아야 입장 체인이 상태에 반영된다.
        await store.receive(\.home.delegate.roomJoined)

        guard case let .roomDetail(screen) = store.state else {
            Issue.record("방 상세가 아니다: \(store.state.screenID)")
            return
        }
        #expect(screen.roomDetail.room.id == Self.card.id)
    }

    @Test("다른 화면에서 링크를 받으면 홈을 거쳐 입장한다")
    func joinsFromOtherScreen() async throws {
        let store = TestStore(
            initialState: AppFeature.State.roomDetail(AppFeature.RoomDetailScreen(profile: Self.profile, room: .previewPrinted))
        ) {
            AppFeature()
        } withDependencies: {
            $0.joinRoomUseCase = JoinRoomUseCase(run: { _ in Self.card })
        }
        store.exhaustivity = .off

        try await store.send(.inviteLinkOpened(Self.inviteURL()))
        await store.receive(\.home.delegate.roomJoined)

        guard case let .roomDetail(screen) = store.state else {
            Issue.record("방 상세가 아니다: \(store.state.screenID)")
            return
        }
        // 보고 있던 인화 완료 방이 아니라 링크의 방으로 옮겨 갔다.
        #expect(screen.roomDetail.room.id == Self.card.id)
    }

    @Test("프로필 설정을 마친 신규 사용자도 보관된 링크로 입장한다")
    func deliversAfterProfileSetup() async {
        // 링크가 먼저 도착해 보관된 상태에서, 신규 사용자가 프로필 설정을 끝내는 상황.
        let box = LockIsolated<String?>("1928121")
        let store = TestStore(initialState: AppFeature.State.profileSetup(ProfileSetupFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.pendingInviteCode = PendingInviteCode(
                store: { code in box.setValue(code) },
                take: { box.withValue { code in
                    defer { code = nil }
                    return code
                } }
            )
            $0.joinRoomUseCase = JoinRoomUseCase(run: { _ in Self.card })
        }
        store.exhaustivity = .off

        await store.send(.profileSetup(.delegate(.setupCompleted(Self.profile))))
        await store.receive(\.home.delegate.roomJoined)

        guard case let .roomDetail(screen) = store.state else {
            Issue.record("방 상세가 아니다: \(store.state.screenID)")
            return
        }
        #expect(screen.roomDetail.room.id == Self.card.id)
        #expect(box.value == nil)
    }

    @Test("로그인 전에 받은 링크는 보관했다가 홈 도달 후 입장한다")
    func coldStartHoldsCodeUntilHome() async throws {
        // 보관함을 실제 동작(넣고 한 번 꺼내기)으로 주입한다 — 보관·전달이 이 테스트의 관심사다.
        let box = LockIsolated<String?>(nil)
        let store = TestStore(initialState: AppFeature.State.launching) {
            AppFeature()
        } withDependencies: {
            $0.pendingInviteCode = PendingInviteCode(
                store: { code in box.setValue(code) },
                take: { box.withValue { code in
                    defer { code = nil }
                    return code
                } }
            )
            $0.joinRoomUseCase = JoinRoomUseCase(run: { _ in Self.card })
        }
        store.exhaustivity = .off

        // 스플래시에서 링크 도착 — 화면은 그대로, 코드만 보관된다.
        try await store.send(.inviteLinkOpened(Self.inviteURL()))
        await store.finish() // 보관 이펙트가 끝난 뒤에 박스를 봐야 한다
        #expect(box.value == "1928121")

        // 프로필 조회가 끝나 홈으로 — 보관된 코드가 입장으로 이어진다.
        await store.send(.profileResponse(.success(Self.profile)))
        await store.receive(\.home.delegate.roomJoined)

        guard case let .roomDetail(screen) = store.state else {
            Issue.record("방 상세가 아니다: \(store.state.screenID)")
            return
        }
        #expect(screen.roomDetail.room.id == Self.card.id)
        #expect(box.value == nil) // 꺼낸 뒤 비워졌다
    }
}
