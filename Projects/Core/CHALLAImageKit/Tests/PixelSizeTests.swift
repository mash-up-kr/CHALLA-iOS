@testable import CHALLAImageKit
import CoreGraphics
import Testing

struct PixelSizeTests {

    @Test("정수 생성자는 값을 그대로 보관한다")
    func storesIntegerValues() {
        let size = PixelSize(width: 200, height: 300)

        #expect(size.width == 200)
        #expect(size.height == 300)
    }

    @Test("포인트×배율이 딱 떨어지면 그대로 픽셀이 된다")
    func convertsExactPointSize() {
        let size = PixelSize(pointSize: CGSize(width: 100, height: 100), scale: 3)

        #expect(size.width == 300)
        #expect(size.height == 300)
    }

    @Test("포인트×배율이 소수면 올림한다")
    func roundsUpFractionalPixels() {
        // 33.3 * 3 = 99.9 → 올림 100 (내림이면 99라 실패)
        let size = PixelSize(pointSize: CGSize(width: 33.3, height: 33.3), scale: 3)

        #expect(size.width == 100)
        #expect(size.height == 100)
    }

    @Test("음수 픽셀은 0으로 보정한다")
    func clampsNegativeToZero() {
        let size = PixelSize(width: -5, height: 100)

        #expect(size.width == 0)
        #expect(size.height == 100)
    }

    @Test("같은 값이면 동등하고 Set에서 하나로 취급된다")
    func isHashableForCacheKey() {
        let fromPixels = PixelSize(width: 300, height: 300)
        let fromPoints = PixelSize(pointSize: CGSize(width: 100, height: 100), scale: 3)

        #expect(fromPixels == fromPoints)
        #expect(Set([fromPixels, fromPoints]).count == 1)
    }
}
