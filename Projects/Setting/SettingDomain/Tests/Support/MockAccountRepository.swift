@testable import SettingDomain
import Foundation

/// 테스트용 계정 저장소. 실패 여부를 생성 시점에 정한다.
///
/// 락 없이 두는 이유는 `MockSettingsRepository` 주석 참고.
final class MockAccountRepository: AccountRepository, @unchecked Sendable {

    private let signOutError: SettingError?
    private let deleteError: SettingError?

    private(set) var signOutCallCount = 0

    init(signOutError: SettingError? = nil, deleteError: SettingError? = nil) {
        self.signOutError = signOutError
        self.deleteError = deleteError
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
    }

    func deleteAccount() async throws {
        if let deleteError {
            throw deleteError
        }
    }
}
