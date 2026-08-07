import SwiftUI

/// ``CHALLAAsyncImage``의 로딩 상태. 뷰는 항상 셋 중 정확히 하나의 상태에 있다.
///
/// SwiftUI 내장 `AsyncImagePhase`와 같은 모양으로 맞춰, 표준 `AsyncImage`를 아는 사람이
/// 그대로 읽을 수 있게 한다.
public enum CHALLAAsyncImagePhase {

    /// 아직 로딩 전이거나 로딩 중 — 표시할 것이 없다. (placeholder를 보여줄 상태)
    case empty

    /// 로딩 성공 — 표시할 이미지.
    case success(Image)

    /// 로딩 실패 — 원인 에러. (대부분 `ImageLoadingError`)
    case failure(Error)

    /// 성공 상태면 이미지, 아니면 nil. (간편 접근용)
    public var image: Image? {
        guard case let .success(image) = self else { return nil }
        return image
    }

    /// 실패 상태면 에러, 아니면 nil. (간편 접근용)
    public var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
