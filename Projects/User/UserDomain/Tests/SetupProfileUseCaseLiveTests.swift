import Foundation
import Testing
import UserDomain

@Suite("SetupProfileUseCase.live")
struct SetupProfileUseCaseLiveTests {

    private static let imageData = Data("image".utf8)
    private static let draft = ProfileDraft(nickname: "챌라", imageData: imageData)
    private static let uploadedURL = URL(string: "https://cdn.example.com/p.jpg")!
    private static let profile = UserProfile(
        id: 1,
        nickname: "챌라",
        imageURL: URL(string: "https://example.com/p.png")
    )

    private struct Fixture {
        let useCase: SetupProfileUseCase
        let repository: MockUserRepository
        let uploader: MockProfileImageUploader
    }

    private static func makeFixture(
        updateResult: Result<UserProfile, UserError> = .success(profile),
        uploadResult: Result<URL, UserError> = .success(uploadedURL)
    ) -> Fixture {
        let repository = MockUserRepository(updateResult: updateResult)
        let uploader = MockProfileImageUploader(result: uploadResult)
        return Fixture(
            useCase: .live(repository: repository, uploader: uploader),
            repository: repository,
            uploader: uploader
        )
    }

    @Test("성공 — 이미지를 먼저 올리고, 받은 URL과 닉네임을 저장소에 넘긴다")
    func successUploadsThenSaves() async throws {
        let fixture = Self.makeFixture()

        let result = try await fixture.useCase.run(Self.draft)

        #expect(result == Self.profile)
        #expect(fixture.uploader.uploaded == [Self.imageData])
        #expect(fixture.repository.updates == [.init(nickname: "챌라", imageURL: Self.uploadedURL)])
    }

    @Test("이미지가 없으면 업로드를 건너뛰고 imageURL 없이 저장한다")
    func withoutImageSkipsUpload() async throws {
        let fixture = Self.makeFixture()

        _ = try await fixture.useCase.run(ProfileDraft(nickname: "챌라"))

        #expect(fixture.uploader.uploaded.isEmpty)
        #expect(fixture.repository.updates == [.init(nickname: "챌라", imageURL: nil)])
    }

    @Test("업로드 실패 — 저장소를 호출하지 않는다 (사진 없는 프로필이 저장되면 안 된다)")
    func uploadFailureStopsBeforeSaving() async {
        let fixture = Self.makeFixture(uploadResult: .failure(.network))

        await #expect(throws: UserError.network) {
            _ = try await fixture.useCase.run(Self.draft)
        }
        #expect(fixture.repository.updates.isEmpty)
    }

    @Test("닉네임 무효 — 업로드도 저장도 하지 않고 invalidNickname을 던진다")
    func invalidNicknameBlocksBeforeAnyCall() async {
        let fixture = Self.makeFixture()

        await #expect(throws: UserError.invalidNickname(.empty)) {
            _ = try await fixture.useCase.run(ProfileDraft(nickname: " "))
        }
        await #expect(throws: UserError.invalidNickname(.tooLong(limit: 10))) {
            _ = try await fixture.useCase.run(ProfileDraft(nickname: "나는야멋쟁이토마토임다"))
        }
        #expect(fixture.uploader.uploaded.isEmpty)
        #expect(fixture.repository.updates.isEmpty)
    }

    @Test("저장소 오류(.network)는 그대로 전파된다")
    func repositoryErrorPropagates() async {
        let fixture = Self.makeFixture(updateResult: .failure(.network))

        await #expect(throws: UserError.network) {
            _ = try await fixture.useCase.run(Self.draft)
        }
    }
}
