import CHALLADesignSystem
import SwiftUI

/// 필름 한 칸 — 사진 위아래로 검은 여백이 남는다.
///
/// **`CHALLAAsyncImage`를 쓰지 않는다** (이미지 로딩 규칙의 예외).
/// 그쪽은 칸이 화면에 나타난 뒤에 사진을 받기 시작하고, 도착하면 0.25초에 걸쳐 서서히 나타낸다.
/// 목록처럼 천천히 보는 화면에는 맞지만, 이 필름은 칸 하나가 0.3~0.5초 만에 지나가서
/// **사진이 다 나타나기도 전에 화면을 벗어난다** — 검은 칸만 지나가는 것처럼 보인다.
///
/// 그래서 사진은 `PrintNoticePhotoStore`가 미리 받아 두고, 여기서는 받아 둔 것을 그 자리에서 그린다.
/// 받아오는 창구는 그대로 `ImageLoader`다 — 그리는 시점만 앞당겼다.
struct FilmFrame: View {

    /// 미리 받아 둔 사진. 아직 없으면 검은 칸으로 남는다.
    let image: Image?

    /// `Color.clear`가 칸 크기를 잡고 사진을 그 위에 얹는다 (`CHALLAFilmCard`와 같은 방식).
    /// `scaledToFill`은 긴 변이 칸 밖으로 넘치는데, 사진을 그대로 넣으면 넘친 크기가 칸 크기가 된다.
    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .frame(width: PrintNoticeMetric.photoWidth, height: PrintNoticeMetric.photoHeight)
            // 아직 못 받은 칸은 필름 바탕과 같은 색으로 둔다 — 빈 칸이 따로 눈에 띄지 않는다.
            .background(CHALLAColor.Static.black)
            .overlay {
                Rectangle()
                    .stroke(CHALLAColor.Line.normal, lineWidth: PrintNoticeMetric.photoBorderWidth)
            }
            .frame(height: PrintNoticeMetric.frameHeight)
    }
}

/// 필름 좌우의 천공 띠. 필름 전체 길이에 걸쳐 일정한 간격으로 이어진다 —
/// 구멍 간격(24)이 칸 높이(151.25)로 나누어떨어지지 않아 칸마다 나눠 그리면 경계에서 어긋난다.
struct FilmPerforation: View {

    /// 필름 전체 길이.
    let height: CGFloat

    var body: some View {
        VStack(spacing: PrintNoticeMetric.holeSpacing) {
            ForEach(0 ..< holeCount, id: \.self) { _ in
                Rectangle()
                    .fill(CHALLAColor.Static.white.opacity(PrintNoticeMetric.holeOpacity))
                    .frame(width: PrintNoticeMetric.holeWidth, height: PrintNoticeMetric.holeHeight)
            }
        }
        .padding(.top, PrintNoticeMetric.holeTopInset)
        .frame(width: PrintNoticeMetric.perforationWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var holeCount: Int {
        max(0, Int((height - PrintNoticeMetric.holeTopInset) / PrintNoticeMetric.holePitch))
    }
}
