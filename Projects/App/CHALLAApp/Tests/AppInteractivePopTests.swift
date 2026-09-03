@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import RoomDomain
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — `withDependencies`에 넘기는 `@Sendable` 클로저가 액터 경계를 넘어 읽는다.
private enum PopFixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let card = RoomCard.previewShooting
}

@MainActor
@Suite("AppFeature — 엣지 스와이프 pop")
struct AppInteractivePopTests {

    private static func store(initialState: AppFeature.State) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
        }
    }

    @Test("엣지 스와이프 pop은 방 상세에서 직전 목록을 시딩한 홈으로 돌아간다")
    func popsRoomDetailToHomeBySwipe() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: PopFixture.profile,
                    room: PopFixture.card.room,
                    homeCards: [PopFixture.card]
                )
            )
        )

        await store.send(.popGestureCompleted) {
            $0 = .home(AppFeature.HomeScreen(profile: PopFixture.profile, cards: [PopFixture.card]))
        }
    }

    @Test("엣지 스와이프 pop은 사진 상세에서 방 상세를 새로 만들어 돌아간다")
    func popsPhotoDetailToRoomDetailBySwipe() async {
        let store = Self.store(
            initialState: .photoDetail(
                AppFeature.PhotoDetailScreen(
                    profile: PopFixture.profile,
                    room: PopFixture.card.room,
                    initialPhotoID: "photo-1"
                )
            )
        )

        await store.send(.popGestureCompleted) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(profile: PopFixture.profile, room: PopFixture.card.room)
            )
        }
    }

    @Test("엣지 스와이프 pop은 채팅에서 방 상세를 새로 만들어 돌아간다")
    func popsChatToRoomDetailBySwipe() async {
        let store = Self.store(
            initialState: .chat(
                AppFeature.ChatScreen(profile: PopFixture.profile, room: PopFixture.card.room)
            )
        )

        await store.send(.popGestureCompleted) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(profile: PopFixture.profile, room: PopFixture.card.room)
            )
        }
    }

    @Test("엣지 스와이프 pop은 설정에서 홈으로 돌아간다")
    func popsSettingToHomeBySwipe() async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: PopFixture.profile))
        )

        await store.send(.popGestureCompleted) {
            $0 = .home(AppFeature.HomeScreen(profile: PopFixture.profile))
        }
    }

    @Test("엣지 스와이프 pop은 편집 취소와 같다 — 변경을 반영하지 않고 설정으로 돌아간다")
    func popsProfileEditToSettingDiscardingChanges() async {
        var editScreen = AppFeature.ProfileEditScreen(profile: PopFixture.profile)
        editScreen.edit.nickname = "저장 안 된 이름"
        let store = Self.store(initialState: .profileEdit(editScreen))

        await store.send(.popGestureCompleted) {
            $0 = .setting(AppFeature.SettingScreen(profile: PopFixture.profile))
        }
    }

    @Test("pop할 부모가 없는 화면에서는 스와이프 완료가 아무것도 하지 않는다")
    func ignoresPopGestureOnRootScreens() async {
        let store = Self.store(initialState: .home(AppFeature.HomeScreen(profile: PopFixture.profile)))

        await store.send(.popGestureCompleted)
    }
}
