import Foundation
import SettingDomain

/// 데모용 계정 저장소 — 성공/실패와 지연을 실행 인자로 못 박는다.
///
/// 진행 중 상태(버튼 비활성)와 실패 얼럿을 캡처하려면 지연과 실패를 인자로 정할 수 있어야 한다.
/// 실행 앱은 `AuthDomain.LogoutUseCase`를 감싼 어댑터를 주입한다.
struct StubAccountRepository: AccountRepository {

    /// `nil`이면 성공한다.
    let failure: SettingError?

    /// 진행 중 상태를 눈으로 확인할 수 있을 만큼만 지연시킨다.
    let delay: Duration

    init(failure: SettingError? = nil, delay: Duration = .milliseconds(400)) {
        self.failure = failure
        self.delay = delay
    }

    func signOut() async throws {
        try await perform()
    }

    func deleteAccount() async throws {
        try await perform()
    }

    private func perform() async throws {
        try? await Task.sleep(for: delay)
        if let failure {
            throw failure
        }
    }
}
