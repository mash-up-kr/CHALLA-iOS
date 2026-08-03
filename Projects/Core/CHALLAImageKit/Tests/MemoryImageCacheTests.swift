@testable import CHALLAImageKit
import Foundation
import Testing
import UIKit

struct MemoryImageCacheTests {

    private let url = URL(string: "https://example.com/photo.jpg")!
    private let size300 = PixelSize(width: 300, height: 300)
    private let size1200 = PixelSize(width: 1200, height: 1200)

    /// 테스트용 작은 이미지를 만든다.
    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    @Test("저장한 이미지는 같은 키로 조회하면 그대로 나온다")
    func returnsInsertedImage() {
        let cache = MemoryImageCache(costLimit: 10 * 1024 * 1024)
        let key = ImageCacheKey(url: url, pixelSize: size300)
        let image = makeImage()

        cache.insert(image, for: key, cost: 100)

        #expect(cache.image(for: key) === image)
    }

    @Test("저장하지 않은 키를 조회하면 nil이다")
    func returnsNilForMissingKey() {
        let cache = MemoryImageCache(costLimit: 10 * 1024 * 1024)
        let key = ImageCacheKey(url: url, pixelSize: size300)

        #expect(cache.image(for: key) == nil)
    }

    @Test("같은 URL이라도 크기가 다르면 별도 항목으로 취급한다")
    func distinguishesBySize() {
        let cache = MemoryImageCache(costLimit: 10 * 1024 * 1024)
        let gridKey = ImageCacheKey(url: url, pixelSize: size300)
        let detailKey = ImageCacheKey(url: url, pixelSize: size1200)

        cache.insert(makeImage(), for: gridKey, cost: 100)

        // 300px로 저장했으므로 1200px 조회는 캐시 미스여야 한다
        #expect(cache.image(for: gridKey) != nil)
        #expect(cache.image(for: detailKey) == nil)
    }

    @Test("removeAll 후에는 조회하면 nil이다")
    func removeAllClearsCache() {
        let cache = MemoryImageCache(costLimit: 10 * 1024 * 1024)
        let key = ImageCacheKey(url: url, pixelSize: size300)
        cache.insert(makeImage(), for: key, cost: 100)

        cache.removeAll()

        #expect(cache.image(for: key) == nil)
    }
}
