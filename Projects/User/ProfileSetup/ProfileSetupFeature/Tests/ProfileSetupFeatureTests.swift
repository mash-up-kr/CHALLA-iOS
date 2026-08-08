import ComposableArchitecture
import Foundation
import PhotoLibrary
import ProfileSetupFeature
import Testing
import UserDomain

@MainActor
@Suite("ProfileSetupFeature")
struct ProfileSetupFeatureTests: ProfileSetupTestSupport {

    // MARK: - 화면 진입

    @Test("진입 — 닉네임 필드에 포커스가 잡혀 바로 키보드 입력을 받는다")
    func taskFocusesNicknameField() async {
        let store = makeStore(clock: TestClock())

        await store.send(.view(.task)) {
            $0.isNicknameFocused = true
        }
    }

    @Test("환영 화면으로 재진입해도 포커스를 잡지 않는다 — 읽기 전용 단계다")
    func taskDoesNotFocusOutsideEditing() async {
        var state = ProfileSetupFeature.State(nickname: "챌라")
        state.phase = .welcome
        let store = makeStore(initialState: state, clock: TestClock())

        await store.send(.view(.task))
    }

    @Test("사진 메뉴가 열린 채 진입하면 포커스를 잡지 않는다 — 키보드가 드로어를 덮는다")
    func taskDoesNotFocusWhilePhotoMenuPresented() async {
        var state = ProfileSetupFeature.State()
        state.isPhotoMenuPresented = true
        let store = makeStore(initialState: state, clock: TestClock())

        await store.send(.view(.task))
    }

    @Test("사진 피커가 열린 채 진입해도 포커스를 잡지 않는다")
    func taskDoesNotFocusWhilePhotoPickerPresented() async {
        var state = ProfileSetupFeature.State()
        state.isPhotoPickerPresented = true
        let store = makeStore(initialState: state, clock: TestClock())

        await store.send(.view(.task))
    }

    // MARK: - 닉네임 입력

    @Test("유효 닉네임 입력 — 값이 반영되고 CTA가 활성화된다")
    func validNicknameInput() async {
        let store = makeStore(clock: TestClock())

        await store.send(\.binding.nickname, "챌라") {
            $0.nickname = "챌라"
        }
        #expect(store.state.isSubmittable)
        #expect(store.state.isCTAVisible)
        #expect(store.state.isCTAEnabled)
    }

    @Test("11자 입력 — 값은 그대로 남고 오류 표시 + 토스트, CTA는 즉시 비활성")
    func overLengthInputMarksInvalid() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(\.binding.nickname, Self.elevenChars) {
            $0.nickname = Self.elevenChars // 입력한 그대로 반영된다 — 값 자체로 위반을 판정하기 위해
            $0.toast = .init(message: Self.tooLong.userMessage)
        }
        #expect(store.state.nicknameViolation == Self.tooLong)
        #expect(store.state.isSubmittable == false)
        #expect(store.state.isCTAEnabled == false)

        // 한 글자만 지우면 타이머를 기다리지 않고 그 자리에서 정상으로 돌아온다
        await store.send(\.binding.nickname, Self.tenChars) {
            $0.nickname = Self.tenChars
            $0.toast = nil
        }
        #expect(store.state.nicknameViolation == nil)
        #expect(store.state.isCTAEnabled)
    }

    @Test("길이 초과 상태에서 시작하기 탭은 가드에 막힌다")
    func startTapWhileOverLengthIsIgnored() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(\.binding.nickname, Self.elevenChars) {
            $0.nickname = Self.elevenChars
            $0.toast = .init(message: Self.tooLong.userMessage)
        }
        // 상태 변화도, 제출 이펙트도 없어야 한다 (클로저 생략 = 무변화 단언)
        await store.send(.view(.startButtonTapped))

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("토스트는 2초 뒤 사라지지만 값이 그대로면 오류 표시·비활성은 유지된다")
    func toastDismissesButInvalidStateRemains() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(\.binding.nickname, Self.elevenChars) {
            $0.nickname = Self.elevenChars
            $0.toast = .init(message: Self.tooLong.userMessage)
        }

        await clock.advance(by: .seconds(1))
        #expect(store.state.toast != nil) // 1초 시점엔 아직 유지

        await clock.advance(by: .seconds(1))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
        // 안내만 거뒀을 뿐 값은 여전히 11자다 — 필드는 빨갛고 CTA는 비활성이어야 한다
        #expect(store.state.nicknameViolation == Self.tooLong)
        #expect(store.state.isCTAEnabled == false)
    }

    @Test("초과 입력 뒤 정상 입력 — 토스트 즉시 해제 + 타이머 취소")
    func normalInputClearsToastImmediately() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(\.binding.nickname, Self.elevenChars) {
            $0.nickname = Self.elevenChars
            $0.toast = .init(message: Self.tooLong.userMessage)
        }
        await store.send(\.binding.nickname, "챌라") {
            $0.nickname = "챌라"
            $0.toast = nil
        }
        #expect(store.state.nicknameViolation == nil)

        // 타이머가 취소됐으므로 시간이 지나도 .toastDismissed가 오지 않는다 (exhaustive가 보장)
        await clock.advance(by: .seconds(2))
    }

    @Test("초과 입력 연타 — 토스트 타이머는 마지막 입력 기준으로 리셋된다")
    func repeatedOverLengthInputResetsToastTimer() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(\.binding.nickname, Self.elevenChars) {
            $0.nickname = Self.elevenChars
            $0.toast = .init(message: Self.tooLong.userMessage)
        }

        await clock.advance(by: .seconds(1))
        // 한 글자 더 — 토스트 문구는 같아 상태는 그대로고 타이머만 리셋된다
        await store.send(\.binding.nickname, Self.elevenChars + "라") {
            $0.nickname = Self.elevenChars + "라"
        }

        await clock.advance(by: .seconds(1)) // 첫 타이머 시점(2초) — 발화하면 안 된다
        #expect(store.state.toast != nil)

        await clock.advance(by: .seconds(1)) // 마지막 입력 기준 2초
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("같은 값 echo write는 토스트를 소거하지 않는다 (TextField 포커스 진입 회귀 방지)")
    func echoWriteDoesNotClearToast() async {
        var seeded = ProfileSetupFeature.State(nickname: Self.elevenChars)
        seeded.toast = .init(message: Self.tooLong.userMessage)
        let store = makeStore(initialState: seeded, clock: TestClock())

        // 값이 안 바뀐 바인딩 쓰기 — onChange가 돌지 않아 상태 변화·이펙트 모두 없어야 한다
        await store.send(\.binding.nickname, Self.elevenChars)

        #expect(store.state.nicknameViolation == Self.tooLong)
        #expect(store.state.toast != nil)
    }

    // MARK: - 포커스·가드

    @Test("실행 직후에도 CTA는 보인다 — 빈 값이라 비활성일 뿐")
    func ctaVisibleFromStart() {
        let store = makeStore(clock: TestClock())

        #expect(store.state.isCTAVisible)
        #expect(store.state.isCTAEnabled == false)
    }

    @Test("포커스를 잡아도 CTA 표시 여부는 그대로다")
    func focusKeepsCTAVisible() async {
        let store = makeStore(clock: TestClock())

        await store.send(\.binding.isNicknameFocused, true) {
            $0.isNicknameFocused = true
        }
        #expect(store.state.isCTAVisible)
        #expect(store.state.isCTAEnabled == false)
    }

    @Test("환영 화면에서는 CTA가 사라진다")
    func ctaHiddenOnWelcome() {
        var seeded = ProfileSetupFeature.State(nickname: "챌라")
        seeded.phase = .welcome
        let store = makeStore(initialState: seeded, clock: TestClock())

        #expect(store.state.isCTAVisible == false)
    }

    @Test("빈 값으로 시작하기 탭 — 가드에 막혀 상태 변화도 이펙트도 없다")
    func startTapWithEmptyNicknameIsIgnored() async {
        let store = makeStore(clock: TestClock())

        await store.send(.view(.startButtonTapped))
    }
}
