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

/// 아직 `.main` 밖에 남은 enum 화면들의 엣지 스와이프 pop.
/// `.main` 안(방 상세·사진 상세·채팅)의 스와이프는 NavigationStack이 처리해 여기 오지 않는다 — `MainFeatureTests` 참고.
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

    @Test("엣지 스와이프 pop은 설정에서 메인(홈)으로 돌아간다")
    func popsSettingToMainBySwipe() async {
        let store = Self.store(
            initialState: .setting(AppFeature.SettingScreen(profile: PopFixture.profile))
        )

        await store.send(.popGestureCompleted) {
            $0 = .main(MainFeature.State(profile: PopFixture.profile))
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
        let store = Self.store(initialState: .main(MainFeature.State(profile: PopFixture.profile)))

        await store.send(.popGestureCompleted)
    }
}
