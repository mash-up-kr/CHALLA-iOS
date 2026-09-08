import Foundation
import PhotoDomain

/// 이 모듈의 `#Preview`가 함께 쓰는 가짜 값.
enum PreviewSamples {

    /// 프리뷰용 가짜 사진. 사진 6장을 돌려 쓴다 — 슬롯마다 다른 주소를 주면 수십 건이 한꺼번에
    /// 나가 picsum이 막고, 같은 주소는 이미지 로더가 캐시로 재사용한다.
    static func photos(count: Int) -> [Photo] {
        (0 ..< count).compactMap { index in
            guard let url = URL(string: "https://picsum.photos/seed/challa-slot\(index % 6)/300/400")
            else { return nil }

            return Photo(
                id: "\(index)",
                imageURL: url,
                author: PhotoAuthor(id: "author", nickname: "찰나둥이"),
                capturedAt: .now
            )
        }
    }
}
