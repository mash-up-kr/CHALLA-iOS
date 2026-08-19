import Foundation
import PhotoDomain

/// 리액션 반영 결과를 들고 있는 메모리 저장소.
actor DemoPhotoStore {

    private var photos: [Photo]

    init(photos: [Photo]) {
        self.photos = photos
    }

    func all() -> [Photo] {
        photos
    }

    func setReaction(photoID: String, kind: ReactionKind, isOn: Bool, userID: String) -> Photo? {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return nil }
        photos[index] = photos[index].settingReaction(kind, by: userID, isOn: isOn)
        return photos[index]
    }
}
