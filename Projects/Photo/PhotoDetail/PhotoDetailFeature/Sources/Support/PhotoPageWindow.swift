import Foundation

/// 사진 점 표시가 한 번에 보여줄 점의 범위를 정한다.
/// 현재 사진을 가운데 두되 양 끝에서는 가장자리에 붙는다. 뷰 격리와 무관한 순수 규칙이라 별도로 뒀다.
enum PhotoPageWindow {

    /// 한 번에 그리는 점의 최대 개수. 시안이 점 5개를 그린다 (10 · 10 · 10 · 8 · 6).
    static let maxVisible = 5

    /// 현재 사진을 가운데 두는 범위. 양 끝에서는 가장자리에 붙는다.
    static func indices(count: Int, current: Int) -> Range<Int> {
        guard count > maxVisible else { return 0 ..< max(count, 0) }
        let half = maxVisible / 2
        let start = min(max(current - half, 0), count - maxVisible)
        return start ..< (start + maxVisible)
    }
}
