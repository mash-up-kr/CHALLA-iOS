import ComposableArchitecture
import Foundation
import PhotoDomain
import PhotoLibrary

/// 데모의 의존성 조립 지점. 여기서만 구체 구현을 만든다.
///
/// 사진 조회는 Mock이지만 사진첩 저장은 실제 구현을 쓴다. 저장은 시뮬레이터에서 직접 확인해야 검증된다.
enum CompositionRoot {

    static func registerDependencies(
        for demoState: DemoLaunchArguments.State,
        into values: inout DependencyValues
    ) {
        let repository = DemoPhotoRepository(scenario: scenario(for: demoState))

        values.fetchRoomPhotosUseCase = .live(repository: repository)
        values.setPhotoReactionUseCase = .live(repository: repository)
        values.deletePhotoReactionUseCase = .live(repository: repository)
        values.savePhotoUseCase = .live(repository: repository, photoLibrary: PhotoLibraryAdapter())
    }

    private static func scenario(for demoState: DemoLaunchArguments.State) -> DemoPhotoRepository.Scenario {
        switch demoState {
        case .default, .printWaiting: .populated(DemoPhotoStore(photos: DemoFixture.photos()))
        case .loading: .neverFinishes
        case .empty: .empty
        case .error: .failure(.network)
        }
    }
}

/// Core의 사진첩 저장을 도메인 인터페이스에 연결한다.
/// Core는 도메인을 모르므로(`Keychain`과 같은 이유) 어댑터가 필요하다. `PhotoData`가 생기면 그쪽으로 옮긴다.
private struct PhotoLibraryAdapter: PhotoLibraryWriting {

    private let store = PhotoLibraryStore()

    func save(imageData: Data) async throws {
        do {
            try await store.save(imageData: imageData)
        } catch PhotoLibraryError.permissionDenied {
            throw PhotoError.permissionDenied
        } catch {
            throw PhotoError.saveFailed
        }
    }
}
