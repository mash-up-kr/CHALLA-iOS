import Foundation

public extension RoomDetailFeature {

    /// 조회가 안 끝난 것과 실패한 것을 구분한다. 상세와 사진 목록이 각자 이 값을 쓴다.
    enum LoadState: Equatable, Sendable {
        case notRequested
        case loading
        case loaded
        case failed
    }
}
