import Foundation
import Testing
import UserDomain

@Suite("FetchMyProfileUseCase.live")
struct FetchMyProfileUseCaseLiveTests {

    @Test("성공 — repository가 돌려준 프로필을 그대로 전달한다")
    func successPassesProfileThrough() async throws {
        let profile = UserProfile(id: 7, nickname: "챌라")
        let useCase = FetchMyProfileUseCase.live(
            repository: MockUserRepository(fetchResult: .success(profile))
        )

        #expect(try await useCase.run() == profile)
    }

    @Test("repository 오류(.unauthorized)는 그대로 전파된다")
    func repositoryErrorPropagates() async {
        let useCase = FetchMyProfileUseCase.live(
            repository: MockUserRepository(fetchResult: .failure(.unauthorized))
        )

        await #expect(throws: UserError.unauthorized) {
            _ = try await useCase.run()
        }
    }
}

@Suite("UserProfile.isProfileCompleted")
struct UserProfileCompletionTests {

    @Test("닉네임이 없으면 미완료 — 프로필 설정 화면으로 보내는 근거")
    func nilNicknameIsIncomplete() {
        #expect(UserProfile(id: 1).isProfileCompleted == false)
    }

    @Test("닉네임이 있으면 완료")
    func presentNicknameIsCompleted() {
        #expect(UserProfile(id: 1, nickname: "챌라").isProfileCompleted)
    }
}
