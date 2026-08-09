import Dependencies
import DependenciesMacros
import Foundation

/// 닉네임을 방어 검증한 뒤 프로필 생성을 저장소에 위임한다.
@DependencyClient
public struct SetupProfileUseCase: Sendable {
    public var run: @Sendable (_ draft: ProfileDraft) async throws -> UserProfile
}

extension SetupProfileUseCase: TestDependencyKey {

    /// liveValue를 두지 않는 이유는 AuthDomain과 동일 — 구체 어댑터를 만들려면 Data를 import해야 한다.
    public static func live(
        repository: any UserRepository,
        uploader: any ProfileImageUploader
    ) -> SetupProfileUseCase {
        SetupProfileUseCase(run: { draft in
            if let violation = NicknameRule.validate(draft.nickname) {
                throw UserError.invalidNickname(violation) // 서버 왕복 전에 차단
            }
            var imageURL: URL?
            if let imageData = draft.imageData {
                // 업로드 실패 시 프로필 저장으로 넘어가지 않는다 — 서버는 스토리지 업로드 실패를 알지 못해
                // 사진 없는 프로필이 저장되고 사용자는 성공으로 오해한다.
                imageURL = try await uploader.upload(imageData)
            }
            return try await repository.updateProfile(nickname: draft.nickname, imageURL: imageURL)
        })
    }

    public static let testValue = SetupProfileUseCase()

    public static let previewValue = SetupProfileUseCase(
        run: { UserProfile(id: 1, nickname: $0.nickname) }
    )
}

public extension DependencyValues {
    var setupProfileUseCase: SetupProfileUseCase {
        get { self[SetupProfileUseCase.self] }
        set { self[SetupProfileUseCase.self] = newValue }
    }
}
