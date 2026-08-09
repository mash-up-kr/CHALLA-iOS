@testable import SettingDomain
import Testing

struct SignOutUseCaseTests {

    @Test("저장소의 로그아웃을 한 번 호출한다")
    func callsRepositorySignOut() async throws {
        let repository = MockAccountRepository()
        let useCase = SignOutUseCase.live(account: repository)

        try await useCase.run()

        #expect(repository.signOutCallCount == 1)
    }

    @Test("로그아웃 실패를 그대로 던진다 — 화면이 얼럿 문구를 고를 수 있어야 한다")
    func propagatesSignOutFailure() async {
        let useCase = SignOutUseCase.live(
            account: MockAccountRepository(signOutError: .network)
        )

        await #expect(throws: SettingError.network) {
            try await useCase.run()
        }
    }
}

struct DeleteAccountUseCaseTests {

    @Test("탈퇴 실패를 그대로 던진다")
    func propagatesDeleteFailure() async {
        let useCase = DeleteAccountUseCase.live(
            account: MockAccountRepository(deleteError: .unknown)
        )

        await #expect(throws: SettingError.unknown) {
            try await useCase.run()
        }
    }
}
