import ComposableArchitecture
import Foundation
import PhotoLibrary
import ProfileSetupFeature
import Testing
import UserDomain

@MainActor
@Suite("ProfileSetupFeature — 프로필 사진")
struct ProfileSetupPhotoTests: ProfileSetupTestSupport {

    @Test("아바타 탭 — 사진 메뉴가 열리고 키보드 포커스는 풀린다")
    func avatarTapOpensPhotoMenu() async {
        var seeded = ProfileSetupFeature.State()
        seeded.isNicknameFocused = true
        let store = makeStore(initialState: seeded, clock: TestClock())

        await store.send(.view(.profileImageButtonTapped)) {
            $0.isNicknameFocused = false
            $0.isPhotoMenuPresented = true
        }
        #expect(store.state.canRemovePhoto == false) // 사진이 없으면 삭제 버튼도 없다
    }

    @Test("제출 중에는 아바타 탭이 무시된다")
    func avatarTapWhileSubmittingIsIgnored() async {
        var seeded = ProfileSetupFeature.State(nickname: "챌라")
        seeded.phase = .submitting
        let store = makeStore(initialState: seeded, clock: TestClock())

        await store.send(.view(.profileImageButtonTapped))
    }

    @Test("앨범에서 선택 — 권한이 있으면 드로어가 닫히고 시스템 피커가 열린다")
    func albumSelectOpensPickerWhenAuthorized() async {
        var seeded = ProfileSetupFeature.State()
        seeded.isPhotoMenuPresented = true
        let store = makeStore(initialState: seeded, clock: TestClock(), photoAuthorization: .limited)

        await store.send(.view(.albumSelectTapped)) {
            $0.isPhotoMenuPresented = false
        }
        await store.receive(\.photoAuthorizationResponse, .limited) { // 일부 허용도 피커는 열린다
            $0.isPhotoPickerPresented = true
        }
    }

    @Test("앨범에서 선택 — 권한이 거부되면 피커 대신 안내 토스트가 뜬다")
    func albumSelectShowsToastWhenDenied() async {
        let clock = TestClock()
        var seeded = ProfileSetupFeature.State()
        seeded.isPhotoMenuPresented = true
        let store = makeStore(initialState: seeded, clock: clock, photoAuthorization: .denied)

        await store.send(.view(.albumSelectTapped)) {
            $0.isPhotoMenuPresented = false
        }
        await store.receive(\.photoAuthorizationResponse, .denied) {
            $0.toast = .init(message: "설정에서 사진 접근을 허용해 주세요")
        }
        #expect(store.state.isPhotoPickerPresented == false)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("사진을 읽어들이면 아바타에 반영되고 선택 항목은 비워진다")
    func loadedPhotoFillsAvatar() async {
        let store = makeStore(clock: TestClock())
        let imageData = Data("image".utf8)

        await store.send(.photoLoadResponse(imageData)) {
            $0.imageData = imageData
        }
        #expect(store.state.canRemovePhoto) // 이제 삭제 버튼이 나온다
    }

    @Test("사진 읽기에 실패하면 아바타는 그대로 두고 토스트만 띄운다")
    func failedPhotoLoadShowsToast() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.photoLoadResponse(nil)) {
            $0.toast = .init(message: "사진을 불러오지 못했어요")
        }
        #expect(store.state.imageData == nil)

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("프로필 사진 삭제 — 이미지가 지워지고 드로어가 닫힌다")
    func removePhotoClearsImage() async {
        var seeded = ProfileSetupFeature.State(imageData: Data("image".utf8))
        seeded.isPhotoMenuPresented = true
        let store = makeStore(initialState: seeded, clock: TestClock())

        await store.send(.view(.photoRemoveTapped)) {
            $0.isPhotoMenuPresented = false
            $0.imageData = nil
        }
        #expect(store.state.canRemovePhoto == false) // 기본 아바타로 되돌아간다
    }

    @Test("닫기 버튼 — 사진 메뉴만 닫고 나머지 상태는 건드리지 않는다")
    func photoMenuDismissKeepsState() async {
        let imageData = Data("image".utf8)
        var seeded = ProfileSetupFeature.State(nickname: "챌라", imageData: imageData)
        seeded.isPhotoMenuPresented = true
        let store = makeStore(initialState: seeded, clock: TestClock())

        await store.send(.view(.photoMenuDismissed)) {
            $0.isPhotoMenuPresented = false
        }
        #expect(store.state.imageData == imageData)
    }
}
