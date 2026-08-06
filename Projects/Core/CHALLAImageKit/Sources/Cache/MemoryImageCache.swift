import UIKit

/// 다운샘플된 `UIImage`를 메모리에 보관하는 캐시. `NSCache`를 감싸 스레드 안전하다.
///
/// NSCache는 총 비용(cost)이 상한을 넘거나 시스템 메모리 압박 시 항목을 자동 방출한다(방출 순서 비보장).
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
///
/// `hash`·`isEqual` 오버라이드는 문법상 선택이지만 여기서는 필수다:
/// NSObject 기본 동등성은 인스턴스(포인터) 비교라, 저장 때와 조회 때 만든 상자가
/// 서로 다른 키로 취급돼 모든 조회가 미스가 된다. 두 오버라이드가 비교 기준을
/// 내용물(`ImageCacheKey`)로 바꾼다. 둘은 반드시 함께 오버라이드한다 —
/// `isEqual`이 참인 두 객체는 `hash`도 같아야 한다는 규칙 때문이다.
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
