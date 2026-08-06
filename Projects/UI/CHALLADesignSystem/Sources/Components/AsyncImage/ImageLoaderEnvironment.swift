import CHALLAImageKit
import SwiftUI

// 이 파일은 @Entry 매크로로 바꾸지 않는다. 맨 아래 swiftformat 줄은 사람용 주석이 아니라
// 자동 변환(environmentEntry 규칙)을 끄는 명령어다 — 지우면 다음 린트 교정 때 @Entry로 바뀐다.
//
// 바꾸지 않는 이유: 기본 로더는 앱 전체가 하나를 공유해야 한다. 로더마다 메모리 캐시가
// 따로라서 로더가 여러 개 생기면 같은 사진을 그 수만큼 다시 받는다. 아래의 static let은
// "최초 접근 때 한 번만 생성"을 언어 차원에서 보장하지만, @Entry가 자동 생성하는 기본값은
// 그 보장이 확인되지 않아 수동 구현을 유지한다.
// swiftformat:disable environmentEntry

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
