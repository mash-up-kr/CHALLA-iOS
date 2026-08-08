import ComposableArchitecture
import Foundation
import UserDomain

/// Mock 의존성 조립 지점 — `UserData`가 없으므로 Mock만 등록한다 (아키텍처 규칙 2의 데모앱 예외).
/// TODO(UserData 착수 시): registerLiveDependencies(into:)를 추가하고 --live 인자로 전환한다.
enum CompositionRoot {

    enum Outcome: Sendable {
        case success
        case failure(UserError)
    }

    static func registerMockDependencies(
        into values: inout DependencyValues,
        outcome: Outcome = .success
    ) {
        values.setupProfileUseCase = SetupProfileUseCase(run: { draft in
            try await Task.sleep(for: .seconds(1.5)) // 로딩 dots를 눈으로 확인할 수 있게 지연
            if case let .failure(error) = outcome {
                throw error
            }
            return UserProfile(id: 1, nickname: draft.nickname)
        })
        // continuousClock은 라이브 그대로 — 토스트/환영 지연을 실제 시간으로 보여준다.
    }
}
