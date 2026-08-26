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

    func photos(inRoom _: Int64) async throws -> [Photo] {
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

    func reactions(forPhotoID photoID: String) async throws -> PhotoReactions {
        guard case let .populated(store) = scenario else { return PhotoReactions() }
        try await Task.sleep(for: latency)
        // 데모는 서버가 없으니 메모리 저장소에 쌓인 리액션을 그대로 돌려준다(재진입 시 스티커·띠 복원).
        guard let photo = await store.photo(id: photoID) else { return PhotoReactions() }
        return PhotoReactions(stickers: photo.reactions, reactedKindsByUser: photo.reactedKindsByUser)
    }

    func setReaction(roomID _: Int64, photoID: String, kind: ReactionKind, isOn _: Bool) async throws {
        guard case let .populated(store) = scenario else { throw PhotoError.unknown }
        try await Task.sleep(for: latency)

        // 데모는 서버가 없으니 메모리 저장소에 반영해 재진입 시에도 스티커가 남게 한다.
        let updated = await store.addReaction(
            photoID: photoID,
            kind: kind,
            userID: DemoFixture.currentUserID
        )
        guard updated != nil else { throw PhotoError.unknown }
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
