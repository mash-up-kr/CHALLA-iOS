import SwiftUI

/// 로컬 커버 사진(`RoomCover.imageData`)을 `Image`로 한 번만 디코딩해 넘긴다 —
/// 색·스티커가 바뀌어 다시 그릴 때마다 JPEG를 풀지 않기 위해서.
public struct RoomCoverPhoto<Content: View>: View {

    private let data: Data?
    private let content: (Image?) -> Content

    @State private var image: Image?

    public init(data: Data?, @ViewBuilder content: @escaping (Image?) -> Content) {
        self.data = data
        self.content = content
        _image = State(initialValue: Self.decode(data))
    }

    public var body: some View {
        content(image)
            .onChange(of: data) { _, data in
                image = Self.decode(data)
            }
    }

    private static func decode(_ data: Data?) -> Image? {
        data.flatMap { UIImage(data: $0) }.map { Image(uiImage: $0) }
    }
}
