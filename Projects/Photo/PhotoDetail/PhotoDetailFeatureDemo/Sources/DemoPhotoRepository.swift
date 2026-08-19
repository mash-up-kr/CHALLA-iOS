import Foundation
import PhotoDomain

/// 데모용 사진 저장소. `PhotoData`가 생기기 전까지 그 자리를 대신한다.
/// 리액션은 메모리에만 저장하고, 원본 이미지만 실제로 내려받는다(사진첩 저장 확인용).
struct DemoPhotoRepository: PhotoRepository {

    /// 데모가 흉내 낼 상황.
    enum Scenario {
        case populated(DemoPhotoStore)
        case neverFinishes
        case empty
        case failure(PhotoError)
    }

    let scenario: Scenario
    /// 응답이 즉시 오면 로딩 표시를 볼 수 없어 일부러 늦춘다.
    private let latency: Duration = .milliseconds(600)

    func photos(inRoom _: String) async throws -> [Photo] {
        switch scenario {
        case let .populated(store):
            try await Task.sleep(for: latency)
            return await store.all()

        case .neverFinishes:
            try await Task.sleep(for: .seconds(60 * 60))
            return []

        case .empty:
            try await Task.sleep(for: latency)
            return []

        case let .failure(error):
            try await Task.sleep(for: latency)
            throw error
        }
    }

    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool) async throws -> Photo {
        guard case let .populated(store) = scenario else { throw PhotoError.unknown }
        try await Task.sleep(for: latency)

        let updated = await store.setReaction(
            photoID: photoID,
            kind: kind,
            isOn: isOn,
            userID: DemoFixture.currentUserID
        )
        guard let updated else { throw PhotoError.unknown }
        return updated
    }

    func imageData(for photo: Photo) async throws -> Data {
        do {
            let (data, _) = try await URLSession.shared.data(from: photo.imageURL)
            return data
        } catch let error as URLError where error.code == .cancelled {
            // 취소를 network 오류로 바꾸면 "네트워크 확인" 얼럿이 잘못 뜬다. 취소는 취소로 올린다.
            // 실 구현(PhotoData)도 이 경로를 그대로 두면 안 된다.
            throw CancellationError()
        } catch {
            throw PhotoError.network
        }
    }
}
