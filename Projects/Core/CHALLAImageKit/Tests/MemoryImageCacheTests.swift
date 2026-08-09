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

    /// 방출 순서를 검증하려면 항목을 서로 구분해야 하므로, URL만 다른 키를 만든다.
    private func makeKey(_ name: String) -> ImageCacheKey {
        ImageCacheKey(url: url.appendingPathComponent(name), pixelSize: size300)
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

    @Test("removeAll 후에는 조회하면 nil이고 총 비용이 0이다")
    func removeAllClearsCache() {
        let cache = MemoryImageCache(costLimit: 10 * 1024 * 1024)
        let key = ImageCacheKey(url: url, pixelSize: size300)
        cache.insert(makeImage(), for: key, cost: 100)

        cache.removeAll()

        #expect(cache.image(for: key) == nil)
        #expect(cache.currentCost == 0)
    }

    @Test("상한을 넘으면 넘은 만큼만, 가장 오래 사용하지 않은 항목부터 방출한다")
    func evictsOldestUntilUnderLimit() {
        let cache = MemoryImageCache(costLimit: 300)
        cache.insert(makeImage(), for: makeKey("a"), cost: 100)
        cache.insert(makeImage(), for: makeKey("b"), cost: 100)
        cache.insert(makeImage(), for: makeKey("c"), cost: 100)

        // 300 → 400이 되어 상한을 넘으므로 가장 오래된 a가 밀려난다.
        cache.insert(makeImage(), for: makeKey("d"), cost: 100)

        #expect(cache.image(for: makeKey("a")) == nil)
        #expect(cache.image(for: makeKey("b")) != nil)
        #expect(cache.image(for: makeKey("c")) != nil)
        #expect(cache.image(for: makeKey("d")) != nil)
        #expect(cache.currentCost == 300)
    }

    @Test("조회로 적중하면 먼저 넣은 항목이라도 방출에서 살아남는다 — 삽입 순서(FIFO)가 아니라 사용 순서(LRU)")
    func hitMovesEntryBackInEvictionOrder() {
        let cache = MemoryImageCache(costLimit: 300)
        cache.insert(makeImage(), for: makeKey("a"), cost: 100)
        cache.insert(makeImage(), for: makeKey("b"), cost: 100)
        cache.insert(makeImage(), for: makeKey("c"), cost: 100)

        // a를 다시 쓰면 b가 가장 오래된 항목이 된다.
        _ = cache.image(for: makeKey("a"))
        cache.insert(makeImage(), for: makeKey("d"), cost: 100)

        #expect(cache.image(for: makeKey("a")) != nil)
        #expect(cache.image(for: makeKey("b")) == nil)
    }

    @Test("같은 키를 덮어써도 총 비용이 이중으로 합산되지 않는다")
    func overwritingKeyDoesNotDoubleCount() {
        let cache = MemoryImageCache(costLimit: 300)
        let key = makeKey("a")

        cache.insert(makeImage(), for: key, cost: 200)
        cache.insert(makeImage(), for: key, cost: 200)

        // 이중 합산이면 400이 되어 상한(300)을 넘고 항목이 방출된다.
        #expect(cache.currentCost == 200)
        #expect(cache.image(for: key) != nil)
    }

    @Test("상한 하나를 통째로 넘는 이미지는 저장 직후 방출된다")
    func evictsSingleItemExceedingLimit() {
        let cache = MemoryImageCache(costLimit: 300)

        cache.insert(makeImage(), for: makeKey("huge"), cost: 400)

        #expect(cache.image(for: makeKey("huge")) == nil)
        #expect(cache.currentCost == 0)
    }
}
