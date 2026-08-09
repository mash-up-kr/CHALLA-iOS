import ComposableArchitecture
import Foundation
import PhotoLibrary
import ProfileSetupFeature
import Testing
import UserDomain

/// 프로필 설정 스위트들이 공유하는 TestStore 조립과 닉네임 길이 상수.
protocol ProfileSetupTestSupport {}

extension ProfileSetupTestSupport {

    static var tenChars: String {
        "나는야멋쟁이토마토임"
    } // 10자
    static var elevenChars: String {
        tenChars + "다"
    } // 11자
    static var tooLong: NicknameRule.Violation {
        .tooLong(limit: NicknameRule.maxLength)
    }

    @MainActor
    func makeStore(
        initialState: ProfileSetupFeature.State = .init(),
        clock: TestClock<Duration>,
        setupProfileUseCase: SetupProfileUseCase = .testValue,
        photoAuthorization: PhotoLibraryAuthorization = .authorized
    ) -> TestStoreOf<ProfileSetupFeature> {
        TestStore(initialState: initialState) {
            ProfileSetupFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.setupProfileUseCase = setupProfileUseCase
            $0.photoLibraryPermission = PhotoLibraryPermissionClient(request: { photoAuthorization })
        }
    }
}
