import SwiftUI

/// URL을 받아 사진을 내려받은 뒤 로드된 `Image` 배열로 넘겨주는 래퍼.
///
/// 디자인 시스템 카드들이 `Image`(로드된 값)를 받고 URL은 다루지 않아 호출부가 변환을 맡는다.
/// `AsyncImage`는 뷰를 돌려줄 뿐 `Image` 값을 꺼낼 수 없어 쓰지 못한다.
///
/// 캐시가 없고 한 장씩 순서대로 받는 임시 구현이다.
/// 받아오기 전에는 빈 배열을 넘겨 카드가 플레이스홀더를 그리게 한다.
///
/// TODO: 이미지 로딩 모듈(이슈 #25)의 `CHALLAAsyncImage`가 생기면 이 파일을 지운다.
///       캐시·병렬 다운로드는 그쪽에서 해결되므로 여기서는 손대지 않는다.
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
                    // try?는 취소 오류까지 nil로 바꾼다. 이 확인이 없으면 취소된 뒤에도 남은 URL을 계속 받는다.
                    guard !Task.isCancelled else { return }
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let uiImage = UIImage(data: data)
                    else { continue }
                    loaded.append(Image(uiImage: uiImage))
                }
                // 취소된 task가 뒤늦게 끝나 새 task가 넣은 이미지를 덮지 않게 한다.
                guard !Task.isCancelled else { return }
                images = loaded
            }
    }
}
