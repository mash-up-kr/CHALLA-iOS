import CHALLAImageKit
import PhotoDomain
import SwiftUI

/// 인화 완료 안내의 필름에 실을 사진을 미리 받아 들고 있는 곳.
///
/// 칸이 그려질 때 사진을 받기 시작하면, 빠르게 지나가는 칸은 도착 전에 화면을 벗어나 검은 채로 지나간다.
/// (`CHALLAAsyncImage`는 칸마다 크기 측정 → 비동기 로드 → 0.25초 페이드인을 거친다.)
/// 그래서 화면과 별개로 미리 받아 두고, 칸은 여기서 꺼내 그 자리에서 그린다.
@MainActor
@Observable
final class PrintNoticePhotoStore {

    /// 받아 둔 사진. 아직 못 받은 것은 없다.
    private(set) var images: [Photo.ID: Image] = [:]

    /// 나올 순서대로 미리 받는다. 한 번에 몇 장씩만 받아 요청이 몰리지 않게 한다.
    ///
    /// `photos`가 곧 나오는 순서다 — 먼저 찍은 사진이 먼저 슬롯을 빠져나온다.
    func warm(_ photos: [Photo], loader: ImageLoader?, scale: CGFloat) async {
        guard let loader else { return }

        // 표시 크기를 정수 pt로 올려 받는다 — 로더의 캐시 키가 `URL + 픽셀 크기`라
        // `CHALLAAsyncImage`가 쓰는 규칙(`ImageLoadSize.quantized`)과 맞춰야 같은 항목을 쓴다.
        let pointSize = CGSize(
            width: PrintNoticeMetric.photoWidth.rounded(.up),
            height: PrintNoticeMetric.photoHeight.rounded(.up)
        )

        await withTaskGroup(of: LoadedPhoto.self) { group in
            var started = 0

            for photo in photos {
                if started >= Const.concurrency, let loaded = await group.next() {
                    store(loaded)
                }
                let id = photo.id
                let url = photo.imageURL
                group.addTask {
                    await LoadedPhoto(
                        id: id,
                        uiImage: try? loader.image(from: url, pointSize: pointSize, scale: scale)
                    )
                }
                started += 1
            }

            for await loaded in group {
                store(loaded)
            }
        }
    }

    /// 들고 있던 사진을 놓는다. 안내가 끝나면 부른다.
    ///
    /// 놓지 않으면 로더의 메모리 캐시가 같은 이미지를 비우려 해도 여기서 붙들고 있어 해제되지 않는다.
    /// 방 하나가 72장이면 70MB쯤 된다.
    func clear() {
        images.removeAll()
    }

    /// 이 사진들이 전부 준비됐는지.
    func hasImages(for photos: some Sequence<Photo>) -> Bool {
        photos.allSatisfy { images[$0.id] != nil }
    }

    private func store(_ loaded: LoadedPhoto) {
        guard let uiImage = loaded.uiImage else { return }
        images[loaded.id] = Image(uiImage: uiImage)
    }

    private enum Const {
        /// 한 번에 받는 장수. 늘리면 빨리 채워지지만 요청이 몰려 첫 칸이 늦어진다.
        static let concurrency = 3
    }
}

/// 미리 받기 한 건의 결과.
private struct LoadedPhoto: Sendable {
    let id: Photo.ID
    let uiImage: UIImage?
}
