import UIKit

/// 다운샘플된 `UIImage`를 메모리에 보관하는 캐시. `NSCache`를 감싸 스레드 안전하다.
///
/// NSCache는 총 비용(cost)이 상한을 넘거나 시스템 메모리 압박 시 오래된 항목을 자동 방출한다.
/// 값(UIImage)만 보관하며, 디스크 저장·다운로드는 상위 계층(로더)이 담당한다.
public final class MemoryImageCache: @unchecked Sendable {

    private let cache = NSCache<CacheKeyBox, UIImage>()

    public init(costLimit: Int) {
        cache.totalCostLimit = costLimit
    }

    /// 캐시에 있으면 이미지를, 없으면 nil을 반환한다.
    public func image(for key: ImageCacheKey) -> UIImage? {
        cache.object(forKey: CacheKeyBox(key))
    }

    /// 이미지를 저장한다. `cost`(보통 바이트 수)가 총 상한 관리에 쓰인다.
    public func insert(_ image: UIImage, for key: ImageCacheKey, cost: Int) {
        cache.setObject(image, forKey: CacheKeyBox(key), cost: cost)
    }

    /// 모든 항목을 비운다. (로그아웃·메모리 경고 시 상위 계층이 호출)
    public func removeAll() {
        cache.removeAllObjects()
    }
}

/// `NSCache`의 키는 객체(class)여야 하는데 `ImageCacheKey`는 struct다.
/// 그래서 키를 감싸는 얇은 객체 상자를 두고, 동등성·해시는 안쪽 struct에 위임한다.
private final class CacheKeyBox: NSObject {

    let key: ImageCacheKey

    init(_ key: ImageCacheKey) {
        self.key = key
    }

    override var hash: Int {
        key.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CacheKeyBox else { return false }
        return other.key == key
    }
}
