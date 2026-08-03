@testable import CHALLAImageKit
import Foundation
import Testing

struct ImageCacheKeyTests {

    private let url = URL(string: "https://example.com/a/photo.jpg?token=abc")!
    private let otherURL = URL(string: "https://example.com/a/other.jpg")!
    private let size300 = PixelSize(width: 300, height: 300)
    private let size1200 = PixelSize(width: 1200, height: 1200)

    @Test("같은 URL·크기면 같은 키다")
    func sameURLAndSizeAreEqual() {
        let a = ImageCacheKey(url: url, pixelSize: size300)
        let b = ImageCacheKey(url: url, pixelSize: size300)

        #expect(a == b)
    }

    @Test("같은 URL이라도 크기가 다르면 다른 키다")
    func sameURLDifferentSizeAreNotEqual() {
        let grid = ImageCacheKey(url: url, pixelSize: size300)
        let detail = ImageCacheKey(url: url, pixelSize: size1200)

        #expect(grid != detail)
    }

    @Test("URL이 다르면 다른 키다")
    func differentURLAreNotEqual() {
        let a = ImageCacheKey(url: url, pixelSize: size300)
        let b = ImageCacheKey(url: otherURL, pixelSize: size300)

        #expect(a != b)
    }

    @Test("같은 키의 storageIdentifier는 항상 동일하다")
    func storageIdentifierIsStable() {
        let a = ImageCacheKey(url: url, pixelSize: size300)
        let b = ImageCacheKey(url: url, pixelSize: size300)

        #expect(a.storageIdentifier == b.storageIdentifier)
    }

    @Test("다른 키의 storageIdentifier는 충돌하지 않는다")
    func storageIdentifierDiffersForDifferentKeys() {
        let grid = ImageCacheKey(url: url, pixelSize: size300)
        let detail = ImageCacheKey(url: url, pixelSize: size1200)
        let other = ImageCacheKey(url: otherURL, pixelSize: size300)

        #expect(grid.storageIdentifier != detail.storageIdentifier)
        #expect(grid.storageIdentifier != other.storageIdentifier)
    }

    @Test("storageIdentifier는 파일명에 안전한 16진수 문자만 포함한다")
    func storageIdentifierIsFilenameSafe() {
        let identifier = ImageCacheKey(url: url, pixelSize: size300).storageIdentifier

        // allSatisfy는 #expect 매크로 밖에서 Bool로 먼저 계산한다
        // (매크로가 키패스 형태를 재조립하다 컴파일 에러를 내는 것을 피함).
        let isAllHexDigits = identifier.allSatisfy(\.isHexDigit)

        #expect(identifier.count == 64) // SHA256 = 32바이트 = 16진수 64자
        #expect(isAllHexDigits)
    }
}
