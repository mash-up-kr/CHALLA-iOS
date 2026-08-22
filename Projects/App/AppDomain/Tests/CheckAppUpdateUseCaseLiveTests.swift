@testable import AppDomain
import Foundation
import Testing

/// 조립 시점에 받은 현재 버전을 Repository에 그대로 전달하는지 검증한다.
private actor SpyAppVersionRepository: AppVersionRepository {

    private let requirement: AppUpdateRequirement
    private(set) var askedVersions: [String] = []

    init(requirement: AppUpdateRequirement) {
        self.requirement = requirement
    }

    func checkUpdateRequirement(currentVersion: String) async throws -> AppUpdateRequirement {
        askedVersions.append(currentVersion)
        return requirement
    }
}

@Suite("CheckAppUpdateUseCase.live")
struct CheckAppUpdateUseCaseLiveTests {

    @Test("조립 시점의 현재 버전으로 Repository에 묻고 결과를 그대로 돌려준다")
    func forwardsCurrentVersionAndResult() async throws {
        let storeURL = URL(string: "https://apps.apple.com/kr/app/id123")
        let repository = SpyAppVersionRepository(requirement: .forced(storeURL: storeURL))
        let useCase = CheckAppUpdateUseCase.live(repository: repository, currentVersion: "1.2.3")

        let requirement = try await useCase.run()

        #expect(requirement == .forced(storeURL: storeURL))
        #expect(await repository.askedVersions == ["1.2.3"])
    }

    @Test("Repository의 실패는 정규화 없이 그대로 던진다 — fail-open 판단은 호출부 몫이다")
    func rethrowsRepositoryFailure() async {
        struct ServerDown: Error {}
        struct FailingRepository: AppVersionRepository {
            func checkUpdateRequirement(currentVersion _: String) async throws -> AppUpdateRequirement {
                throw ServerDown()
            }
        }
        let useCase = CheckAppUpdateUseCase.live(repository: FailingRepository(), currentVersion: "1.0.0")

        await #expect(throws: ServerDown.self) {
            _ = try await useCase.run()
        }
    }
}
