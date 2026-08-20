import Dependencies
import DependenciesMacros

/// 사진 원본을 내려받아 기기 사진첩에 저장한다.
@DependencyClient
public struct SavePhotoUseCase: Sendable {
    public var run: @Sendable (_ photo: Photo) async throws -> Void
}

extension SavePhotoUseCase: TestDependencyKey {

    public static func live(
        repository: any PhotoRepository,
        photoLibrary: any PhotoLibraryWriting
    ) -> SavePhotoUseCase {
        SavePhotoUseCase(run: { photo in
            do {
                let data = try await repository.imageData(for: photo)
                try await photoLibrary.save(imageData: data)
            } catch {
                // 구현체가 계약을 어기고 다른 오류를 던져도 Feature는 PhotoError만 받는다.
                guard error is PhotoError || error is CancellationError else { throw PhotoError.unknown }
                throw error
            }
        })
    }

    public static let testValue = SavePhotoUseCase()
}

public extension DependencyValues {
    var savePhotoUseCase: SavePhotoUseCase {
        get { self[SavePhotoUseCase.self] }
        set { self[SavePhotoUseCase.self] = newValue }
    }
}
