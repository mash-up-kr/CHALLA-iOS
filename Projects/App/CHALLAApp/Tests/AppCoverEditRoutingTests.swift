@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import RoomDomain
import Testing
import UserDomain

private enum CoverEditFixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let card = RoomCard.previewShooting // memberCount 4
    static let renamedTitle = "강릉 여행"
    static let savedCover = RoomCover(
        imageURL: URL(string: "https://cdn.example.com/cover.jpg"),
        sticker: RoomCoverSticker(id: 3, imageURL: nil, color: RoomCoverOptions.preview.colors[2])
    )
}

@MainActor
@Suite("AppFeature — 커버 수정 전이")
struct AppCoverEditRoutingTests {

    private static func store(initialState: AppFeature.State) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
        }
    }

    private static func settingsScreen(room: Room = CoverEditFixture.card.room, title: String? = nil) -> AppFeature.RoomSettingsScreen {
        var screen = AppFeature.RoomSettingsScreen(
            profile: CoverEditFixture.profile,
            room: room,
            homeCards: [CoverEditFixture.card],
            memberCount: CoverEditFixture.card.memberCount
        )
        if let title {
            screen.settings.title = title
        }
        return screen
    }

    private static func coverEditScreen(savedCover: RoomCover? = nil) -> AppFeature.RoomCoverEditScreen {
        var screen = AppFeature.RoomCoverEditScreen(
            profile: CoverEditFixture.profile,
            room: CoverEditFixture.card.room,
            homeCards: [CoverEditFixture.card],
            memberCount: CoverEditFixture.card.memberCount
        )
        if let savedCover {
            screen.coverEdit.cover = savedCover
            screen.coverEdit.savedCover = savedCover
        }
        return screen
    }

    @Test("커버 행을 누르면 방의 현재 커버, 설정의 최신 제목, 인원수를 이어서 커버 수정으로 간다")
    func opensCoverEditWithRoomCoverAndLatestTitle() async {
        let store = Self.store(initialState: .roomSettings(Self.settingsScreen(title: CoverEditFixture.renamedTitle)))

        await store.send(.roomSettings(.delegate(.coverEditRequested))) {
            $0 = .roomCoverEdit(
                AppFeature.RoomCoverEditScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room.renamed(to: CoverEditFixture.renamedTitle),
                    homeCards: [CoverEditFixture.card],
                    memberCount: CoverEditFixture.card.memberCount
                )
            )
        }

        guard case let .roomCoverEdit(screen) = store.state else {
            Issue.record("커버 수정 화면이 아니다")
            return
        }
        #expect(screen.coverEdit.cover == CoverEditFixture.card.room.cover)
        #expect(screen.coverEdit.title == CoverEditFixture.renamedTitle)
        #expect(screen.coverEdit.memberCount == CoverEditFixture.card.memberCount)
    }

    @Test("커버 수정에서 뒤로가면 저장된 커버를 방에 반영해 설정으로 돌아간다")
    func returnsToSettingsWithSavedCover() async {
        let store = Self.store(initialState: .roomCoverEdit(Self.coverEditScreen(savedCover: CoverEditFixture.savedCover)))

        await store.send(.roomCoverEdit(.delegate(.closeTapped))) {
            $0 = .roomSettings(
                Self.settingsScreen(room: CoverEditFixture.card.room.withCover(CoverEditFixture.savedCover))
            )
        }
    }

    @Test("엣지 스와이프 pop은 변경이 없으면 저장 없이 저장된 커버로 설정에 돌아간다")
    func popsCoverEditWithoutChangesSkipsSave() async {
        let store = Self.store(initialState: .roomCoverEdit(Self.coverEditScreen(savedCover: CoverEditFixture.savedCover)))
        store.dependencies.updateRoomCoverUseCase = .testValue // 불리면 미구현 실패

        await store.send(.popGestureCompleted) {
            $0 = .roomSettings(
                Self.settingsScreen(room: CoverEditFixture.card.room.withCover(CoverEditFixture.savedCover))
            )
        }
    }

    @Test("엣지 스와이프 pop은 저장 안 한 변경을 낙관 반영하고 App이 대신 저장한다")
    func popsCoverEditAndSavesInBackground() async {
        var screen = Self.coverEditScreen()
        screen.coverEdit.cover = CoverEditFixture.savedCover // 진입값(.none)과 다르다
        let drafts = LockIsolated<[(Room.ID, RoomCoverDraft)]>([])
        let store = Self.store(initialState: .roomCoverEdit(screen))
        store.dependencies.updateRoomCoverUseCase = UpdateRoomCoverUseCase(run: { roomID, draft in
            drafts.withValue { $0.append((roomID, draft)) }
        })

        await store.send(.popGestureCompleted) {
            $0 = .roomSettings(
                Self.settingsScreen(room: CoverEditFixture.card.room.withCover(CoverEditFixture.savedCover))
            )
        }
        await store.finish()

        #expect(drafts.value.map(\.0) == [CoverEditFixture.card.room.id])
        #expect(drafts.value.map(\.1) == [RoomCoverDraft(cover: CoverEditFixture.savedCover)])
    }

    @Test("스와이프 pop 뒤 저장이 실패하면 설정 화면의 방 커버를 저장 전 값으로 되돌린다")
    func revertsCoverWhenBackgroundSaveFails() async {
        var screen = Self.coverEditScreen()
        screen.coverEdit.cover = CoverEditFixture.savedCover
        let store = Self.store(initialState: .roomCoverEdit(screen))
        store.dependencies.updateRoomCoverUseCase = UpdateRoomCoverUseCase(run: { _, _ in throw RoomError.network })

        await store.send(.popGestureCompleted) {
            $0 = .roomSettings(
                Self.settingsScreen(room: CoverEditFixture.card.room.withCover(CoverEditFixture.savedCover))
            )
        }
        await store.receive(\.roomCoverSaveFailed) {
            $0 = .roomSettings(Self.settingsScreen(room: CoverEditFixture.card.room))
        }
    }

    @Test("저장 실패 응답이 왔을 때 이미 상세로 돌아갔어도 그 방의 커버를 되돌린다")
    func revertsCoverOnDetailScreenToo() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room.withCover(CoverEditFixture.savedCover),
                    homeCards: [CoverEditFixture.card]
                )
            )
        )

        await store.send(.roomCoverSaveFailed(roomID: CoverEditFixture.card.room.id, previousCover: .none)) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room,
                    homeCards: [CoverEditFixture.card]
                )
            )
        }
    }

    @Test("상세를 조회한 뒤 설정으로 가면 인원수는 상세의 멤버 수다")
    func settingsMemberCountComesFromDetail() async {
        var screen = AppFeature.RoomDetailScreen(
            profile: CoverEditFixture.profile,
            room: CoverEditFixture.card.room,
            homeCards: [CoverEditFixture.card]
        )
        screen.roomDetail.detail = RoomDetail.preview // 멤버 3명 — 홈 카드(4명)와 다르다
        let store = Self.store(initialState: .roomDetail(screen))

        await store.send(.roomDetail(.delegate(.settingsTapped))) {
            $0 = .roomSettings(
                AppFeature.RoomSettingsScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room,
                    homeCards: [CoverEditFixture.card],
                    memberCount: RoomDetail.preview.members.count
                )
            )
        }
    }

    @Test("상세 조회 전에 설정으로 가면 인원수는 홈 카드 값으로 메운다")
    func settingsMemberCountFallsBackToHomeCard() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room,
                    homeCards: [CoverEditFixture.card]
                )
            )
        )

        await store.send(.roomDetail(.delegate(.settingsTapped))) {
            $0 = .roomSettings(Self.settingsScreen())
        }
    }

    @Test("상세도 홈 카드도 없으면 인원수는 0이다")
    func settingsMemberCountDefaultsToZero() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(profile: CoverEditFixture.profile, room: CoverEditFixture.card.room)
            )
        )

        await store.send(.roomDetail(.delegate(.settingsTapped))) {
            $0 = .roomSettings(
                AppFeature.RoomSettingsScreen(
                    profile: CoverEditFixture.profile,
                    room: CoverEditFixture.card.room,
                    memberCount: 0
                )
            )
        }
    }
}
