import ComposableArchitecture
import Foundation
import PhotoLibrary
import ProfileSetupFeature
import Testing
import UserDomain

@MainActor
@Suite("ProfileSetupFeature — 제출")
struct ProfileSetupSubmitTests: ProfileSetupTestSupport {

    @Test("정상 제출 — 정규화된 draft 전달 → 환영 → 2초 후 delegate")
    func successfulSubmissionFlow() async {
        let clock = TestClock()
        let imageData = Data("image".utf8)
        let profile = UserProfile(id: 1, nickname: "챌라", imageURL: URL(string: "https://example.com/p.png"))
        let receivedDrafts = LockIsolated<[ProfileDraft]>([])
        let store = makeStore(
            initialState: .init(imageData: imageData),
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { draft in
                receivedDrafts.withValue { $0.append(draft) }
                return profile
            })
        )

        await store.send(\.binding.nickname, " 챌라 ") { // 앞뒤 공백 — 제출 시 trim 검증용
            $0.nickname = " 챌라 "
        }
        await store.send(\.binding.isNicknameFocused, true) {
            $0.isNicknameFocused = true
        }

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
            $0.isNicknameFocused = false
        }
        await store.receive(\.submitResponse.success, profile) {
            $0.savedProfile = profile
            $0.nickname = "챌라" // 서버 응답 닉네임 반영
            $0.phase = .welcome
        }
        // draft에는 정규화(trim)된 닉네임과 새로 고른 사진이 동봉된다
        #expect(receivedDrafts.value == [ProfileDraft(nickname: "챌라", image: .replaced(imageData))])

        await clock.advance(by: .seconds(2))
        await store.receive(\.welcomeFinished)
        await store.receive(\.delegate.setupCompleted, profile)
    }

    @Test("제출 실패(.network) — 편집 복귀 + 토스트, 필드는 빨갛지 않다")
    func submissionFailureShowsToast() async {
        let clock = TestClock()
        let store = makeStore(
            initialState: .init(nickname: "챌라"),
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { _ in throw UserError.network })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
        }
        await store.receive(\.submitResponse.failure, UserError.network) {
            $0.phase = .editing
            $0.toast = .init(message: UserError.network.userMessage)
        }
        #expect(store.state.nicknameViolation == nil) // 실패 원인이 닉네임이 아니므로

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("제출 중 중복 탭은 무시된다 — useCase 호출 1회")
    func duplicateTapWhileSubmittingIsIgnored() async {
        let clock = TestClock()
        let (gate, continuation) = AsyncStream.makeStream(of: Void.self)
        let callCount = LockIsolated(0)
        let profile = UserProfile(id: 1, nickname: "챌라")
        let store = makeStore(
            initialState: .init(nickname: "챌라"),
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { _ in
                callCount.withValue { $0 += 1 }
                for await _ in gate {
                    break
                } // 완료를 보류시켜 "제출 중" 유지
                return profile
            })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
        }
        // 제출 중 재탭 — 상태 변화도, 새 이펙트도 없어야 한다 (클로저 생략 = 무변화 단언)
        await store.send(.view(.startButtonTapped))

        continuation.yield() // 보류 중이던 제출 완료
        await store.receive(\.submitResponse.success, profile) {
            $0.savedProfile = profile
            $0.phase = .welcome
        }
        #expect(callCount.value == 1)

        await clock.advance(by: .seconds(2))
        await store.receive(\.welcomeFinished)
        await store.receive(\.delegate.setupCompleted, profile)
    }

    @Test("재시도 시 떠 있던 실패 토스트는 즉시 정리되고 잔여 타이머도 발화하지 않는다")
    func submitClearsToastAndItsTimer() async {
        let clock = TestClock()
        let profile = UserProfile(id: 1, nickname: "챌라")
        let attempts = LockIsolated(0)
        let store = makeStore(
            initialState: .init(nickname: "챌라"),
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { _ in
                attempts.withValue { $0 += 1 }
                guard attempts.value > 1 else { throw UserError.network }
                return profile
            })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
        }
        await store.receive(\.submitResponse.failure, UserError.network) {
            $0.phase = .editing
            $0.toast = .init(message: UserError.network.userMessage)
        }
        await clock.advance(by: .seconds(1)) // 토스트 타이머 잔여 1초를 남겨둔다

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
            $0.toast = nil
        }
        await store.receive(\.submitResponse.success, profile) {
            $0.savedProfile = profile
            $0.phase = .welcome
        }

        // 잔여 토스트 타이머가 살아 있었다면 이 advance에서 .toastDismissed가 끼어들어 실패한다
        await clock.advance(by: .seconds(2))
        await store.receive(\.welcomeFinished)
        await store.receive(\.delegate.setupCompleted, profile)
    }

    @Test("UserError가 아닌 임의 오류는 .unknown으로 정규화되어 토스트를 띄운다")
    func arbitraryErrorBecomesUnknown() async {
        struct UnexpectedError: Error {} // useCase 계약(UserError 정규화) 밖의 임의 오류
        let clock = TestClock()
        let store = makeStore(
            initialState: .init(nickname: "챌라"),
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { _ in throw UnexpectedError() })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
        }
        await store.receive(\.submitResponse.failure, UserError.unknown) {
            $0.phase = .editing
            $0.toast = .init(message: UserError.unknown.userMessage)
        }

        await clock.advance(by: .seconds(2))
        await store.receive(\.toastDismissed) {
            $0.toast = nil
        }
    }

    @Test("서버가 정규화해 돌려준 닉네임이 성공 시 state에 반영된다")
    func serverNormalizedNicknameIsApplied() async {
        let clock = TestClock()
        let profile = UserProfile(id: 1, nickname: "챌라")
        let store = makeStore(
            initialState: .init(nickname: "챌라 "), // 뒤 공백 — 서버가 정리해 돌려준다고 가정
            clock: clock,
            setupProfileUseCase: SetupProfileUseCase(run: { _ in profile })
        )

        await store.send(.view(.startButtonTapped)) {
            $0.phase = .submitting
        }
        await store.receive(\.submitResponse.success, profile) {
            $0.savedProfile = profile
            $0.nickname = "챌라"
            $0.phase = .welcome
        }
        #expect(store.state.nickname == profile.nickname)

        await clock.advance(by: .seconds(2))
        await store.receive(\.welcomeFinished)
        await store.receive(\.delegate.setupCompleted, profile)
    }
}
