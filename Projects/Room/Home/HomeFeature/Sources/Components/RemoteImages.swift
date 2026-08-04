import SwiftUI

/// URL을 받아 사진을 내려받은 뒤 로드된 `Image` 배열로 넘겨주는 래퍼.
///
/// 디자인 시스템 카드들이 `Image`(로드된 값)를 받고 URL은 다루지 않아 호출부가 변환을 맡는다.
/// `AsyncImage`는 뷰를 돌려줄 뿐 `Image` 값을 꺼낼 수 없어 쓰지 못한다.
///
/// 캐시도 취소도 없는 임시 구현이다 — 이미지 로딩 모듈(이슈 #25)이 생기면 그것으로 교체한다.
/// 받아오기 전에는 빈 배열을 넘겨 카드가 플레이스홀더를 그리게 한다.
struct RemoteImages<Content: View>: View {

    let urls: [URL]
    @ViewBuilder let content: ([Image]) -> Content

    @State private var images: [Image] = []

    var body: some View {
        content(images)
            // urls가 바뀌면 다시 받는다. 화면을 벗어나면 SwiftUI가 task를 취소한다.
            .task(id: urls) {
                var loaded: [Image] = []
                for url in urls {
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let uiImage = UIImage(data: data)
                    else { continue }
                    loaded.append(Image(uiImage: uiImage))
                }
                images = loaded
            }
    }
}
