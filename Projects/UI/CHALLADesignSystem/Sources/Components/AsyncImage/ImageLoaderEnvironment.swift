import CHALLAImageKit
import SwiftUI

/// `ImageLoader`를 뷰 트리에 공급하는 Environment 키.
///
/// 로더는 앱당 1개를 공유해야 한다 — 인스턴스마다 메모리 캐시가 따로라서,
/// 화면마다 새로 만들면 같은 사진을 화면마다 다시 받는다. (actor라 공유는 안전)
private struct CHALLAImageLoaderKey: EnvironmentKey {

    /// 아무도 주입하지 않았을 때 쓰는 기본 로더(.default 설정: 메모리 100MB/디스크 500MB).
    /// static let이라 최초 접근 시 한 번만 생성되어 앱 전체가 같은 인스턴스를 공유한다.
    /// 디스크 캐시 디렉터리 생성이 실패하면(드묾) nil — 로더가 없으면 뷰는 로드하지 않고 placeholder를 유지한다.
    static let defaultValue: ImageLoader? = try? ImageLoader()
}

public extension EnvironmentValues {

    /// ``CHALLAAsyncImage``가 사용할 이미지 로더.
    ///
    /// 기본값만으로 동작하므로 별도 설정 없이 쓸 수 있고,
    /// 커스텀 설정(용량·페처 교체)이나 로그아웃 시 `removeAll()` 연결이 필요하면
    /// 앱 루트에서 직접 만든 로더를 주입해 갈아끼운다:
    /// ```swift
    /// RootView().environment(\.challaImageLoader, myLoader)
    /// ```
    var challaImageLoader: ImageLoader? {
        get { self[CHALLAImageLoaderKey.self] }
        set { self[CHALLAImageLoaderKey.self] = newValue }
    }
}
