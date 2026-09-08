import Dependencies
import DependenciesMacros
import Foundation

/// 전체 다운로드 진행 상황.
public enum SaveAllPhotosEvent: Sendable, Equatable {

    /// `completed`는 성공과 실패를 합한 처리 장수다.
    case progress(completed: Int, saved: Int, total: Int)
    /// 저장 종료 시점의 결과. 취소로 종료된 경우도 포함한다.
    case finished(saved: Int, failed: Int, total: Int)
    /// 사진첩 권한 거부로 중단된 상태.
    case aborted(PhotoError)
}

/// 사진첩에 사진을 순차 저장하고 진행 상황을 반환한다.
/// 저장 순서를 유지하기 위해 병렬 다운로드 결과를 한 장씩 처리한다.
@DependencyClient
public struct SaveAllPhotosUseCase: Sendable {
    public var run: @Sendable (_ photos: [Photo]) -> AsyncStream<SaveAllPhotosEvent> = { _ in .finished }
}

extension SaveAllPhotosUseCase: TestDependencyKey {

    public static func live(
        repository: any PhotoRepository,
        photoLibrary: any PhotoLibraryWriting
    ) -> SaveAllPhotosUseCase {
        SaveAllPhotosUseCase(run: { photos in
            AsyncStream { continuation in
                let task = Task {
                    var saved = 0
                    var failed = 0
                    var completed = 0

                    for await result in repository.imageDataStream(for: photos) {
                        completed += 1

                        switch result {
                        case let .success(data):
                            do {
                                try await photoLibrary.save(imageData: data)
                                saved += 1
                            } catch PhotoError.permissionDenied {
                                // 권한 거부는 이후 사진에도 적용되므로 중단한다.
                                continuation.yield(.aborted(.permissionDenied))
                                continuation.finish()
                                return
                            } catch is CancellationError {
                                // 호출부가 저장 중 상태를 해제할 수 있도록 종료 결과를 전달한다.
                                continuation.yield(
                                    .finished(saved: saved, failed: failed, total: photos.count)
                                )
                                continuation.finish()
                                return
                            } catch {
                                failed += 1
                            }

                        case .failure:
                            failed += 1
                        }

                        continuation.yield(.progress(completed: completed, saved: saved, total: photos.count))
                    }

                    continuation.yield(.finished(saved: saved, failed: failed, total: photos.count))
                    continuation.finish()
                }

                continuation.onTermination = { _ in task.cancel() }
            }
        })
    }

    public static let testValue = SaveAllPhotosUseCase()
}

public extension DependencyValues {
    var saveAllPhotosUseCase: SaveAllPhotosUseCase {
        get { self[SaveAllPhotosUseCase.self] }
        set { self[SaveAllPhotosUseCase.self] = newValue }
    }
}
