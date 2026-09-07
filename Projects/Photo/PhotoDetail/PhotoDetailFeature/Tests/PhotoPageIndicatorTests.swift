@testable import PhotoDetailFeature
import Testing

@Suite("사진 점 표시 창 계산")
struct PhotoPageIndicatorTests {

    private func window(count: Int, current: Int) -> Range<Int> {
        PhotoPageWindow.indices(count: count, current: current)
    }

    @Test("장수가 최대치(5) 이하면 전부 보인다")
    func showsAllWhenFew() {
        #expect(window(count: 3, current: 0) == 0 ..< 3)
        #expect(window(count: 5, current: 2) == 0 ..< 5)
    }

    @Test("장수가 최대치를 넘으면 창이 5개로 고정된다")
    func clampsToMax() {
        #expect(window(count: 10, current: 0).count == 5)
        #expect(window(count: 10, current: 5).count == 5)
        #expect(window(count: 10, current: 9).count == 5)
    }

    @Test("현재 장을 창 가운데에 두되 양 끝에서는 가장자리에 붙는다")
    func centersOnCurrent() {
        #expect(window(count: 10, current: 0) == 0 ..< 5) // 앞끝
        #expect(window(count: 10, current: 5) == 3 ..< 8) // 가운데
        #expect(window(count: 10, current: 9) == 5 ..< 10) // 뒤끝
    }

    @Test("사진이 없으면 빈 창이다")
    func emptyWhenNoPhotos() {
        #expect(window(count: 0, current: 0) == 0 ..< 0)
    }
}
