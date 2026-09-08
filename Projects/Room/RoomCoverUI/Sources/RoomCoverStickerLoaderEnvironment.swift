import CHALLAImageKit
import SwiftUI

// 로더는 앱당 하나를 공유해야 한다 — 로더마다 캐시가 따로라 화면마다 만들면 같은 SVG를 그 수만큼 다시 받는다.
// @Entry의 기본값은 읽을 때마다 새 인스턴스를 만들어 그 공유가 깨지므로, `ImageLoaderEnvironment`와 같이 손으로 쓴다.
// swiftformat:disable environmentEntry

private struct RoomCoverStickerLoaderKey: EnvironmentKey {
    static let defaultValue = VectorDrawingLoader()
}

public extension EnvironmentValues {

    /// ``RoomCoverStickerView``가 스티커 도형을 받아 오는 로더.
    ///
    /// 기본값만으로 동작한다. 테스트·프리뷰에서 네트워크를 끊거나 페처를 갈아끼우려면 주입한다:
    /// ```swift
    /// RootView().environment(\.roomCoverStickerLoader, VectorDrawingLoader(fetcher: stub))
    /// ```
    var roomCoverStickerLoader: VectorDrawingLoader {
        get { self[RoomCoverStickerLoaderKey.self] }
        set { self[RoomCoverStickerLoaderKey.self] = newValue }
    }
}
