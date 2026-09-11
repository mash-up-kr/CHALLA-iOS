import CHALLAImageKit
import CoreGraphics
import Foundation
import PhotoDomain

public extension PrefetchRoomPhotosUseCase {

    /// 홈에서 미리 받아 둘 때 쓰는 구현.
    ///
    /// 화면이 쓰는 것과 **같은 로더, 같은 표시 크기**로 받아야 한다 — 캐시 키가 `URL + 픽셀 크기`라
    /// 크기가 1pt만 달라도 필름이 캐시를 못 쓰고 처음부터 다시 받는다. 미리 받은 것이 통째로 버려진다.
    ///
    /// 셀룰러·저데이터·저전력에서는 받지 않는다 — 들어가지 않을 방까지 미리 받으면 그만큼 데이터를 버린다.
    ///
    /// - Parameters:
    ///   - pointSize: 화면이 사진을 표시할 크기(pt).
    ///   - scale: 화면 배율. 부를 때 읽는다 — 조립 시점에는 아직 화면이 없어 값이 확정되지 않는다.
    static func live(
        repository: any PhotoRepository,
        loader: ImageLoader,
        pointSize: CGSize,
        scale: @escaping @Sendable () async -> CGFloat,
        networkCondition: any NetworkCondition = SystemNetworkCondition.shared
    ) -> PrefetchRoomPhotosUseCase {
        PrefetchRoomPhotosUseCase(run: { roomID in
            guard !networkCondition.isConstrained,
                  let photos = try? await repository.photos(inRoom: roomID),
                  !photos.isEmpty
            else {
                return
            }

            let displayScale = await scale()

            await withTaskGroup(of: Void.self) { group in
                var started = 0
                for photo in photos {
                    // 한 번에 몇 장씩만 받아, 미리 받기가 지금 보고 있는 화면의 이미지를 밀어내지 않게 한다.
                    if started >= Const.concurrency {
                        await group.next()
                    }
                    let url = photo.previewURL
                    group.addTask {
                        _ = try? await loader.image(from: url, pointSize: pointSize, scale: displayScale)
                    }
                    started += 1
                }
            }
        })
    }

    private enum Const {
        /// 화면이 쓰는 값과 같게 둔다 (`PrintNoticePhotoStore`).
        static let concurrency = 3
    }
}
