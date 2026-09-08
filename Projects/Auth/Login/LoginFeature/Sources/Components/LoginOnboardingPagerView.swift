import CHALLADesignSystem
import SwiftUI

/// 로그인 화면 상단의 온보딩 페이저 (Figma onboarding1~5).
///
/// 목업 이미지 + 타이틀이 한 페이지로 좌우 스와이프되고, 인디케이터는 페이저 아래 고정된다.
/// 이미지 에셋은 시안 contents 영역(390×442) 전체 export본이다 — 기기 프레임·하단 페이드가
/// 포함돼 있고 배경은 투명이라, 화면 폭에 맞춰 깔기만 하면 별도 보더·그라데이션이 필요 없다.
struct LoginOnboardingPagerView: View {

    /// 온보딩 한 페이지 — 이미지 에셋 이름 + 타이틀 (줄바꿈 포함, 시안 문구 그대로).
    private struct Page {
        let imageName: String
        let title: String
    }

    private static let pages: [Page] = [
        Page(imageName: "onboarding1", title: "우리만의\n공유 필름 카메라"),
        Page(imageName: "onboarding2", title: "함께 기록하는\n찰나의 순간"),
        Page(imageName: "onboarding3", title: "함께 찍고,\n함께 기다려요"),
        Page(imageName: "onboarding4", title: "3시간 기다리면\n인화 완료!"),
        Page(imageName: "onboarding5", title: "이모지와 댓글로\n자유롭게 소통해요")
    ]

    // MARK: - 프로퍼티

    /// 현재 페이지 인덱스 (0~4).
    @Binding var currentPage: Int

    // MARK: - Body

    var body: some View {
        // 이미지 높이는 폭 비례가 기본이지만, 세로가 좁은 기기(SE 등)에서는 타이틀·인디케이터를
        // 제한 뒤 남는 높이를 상한으로 줄인다 — 안 그러면 아래 로그인 버튼과 겹친다
        GeometryReader { proxy in
            let belowImageHeight = Metric.titleTopSpacing + Metric.titleBoxHeight
                + Metric.indicatorTopSpacing + Metric.dotSize
            let imageHeight = min(
                (proxy.size.width * Metric.imageAspectRatio).rounded(),
                max(0, proxy.size.height - belowImageHeight)
            )

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, page in
                        pageContent(page, imageHeight: imageHeight)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // page 스타일 TabView는 스스로 높이를 가지지 않아 페이지 콘텐츠 높이로 고정한다
                .frame(height: imageHeight + Metric.titleTopSpacing + Metric.titleBoxHeight)

                pageIndicator
                    .padding(.top, Metric.indicatorTopSpacing)
            }
        }
    }

    // MARK: - 페이지

    private func pageContent(_ page: Page, imageHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(page.imageName, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)

            Text(page.title)
                .challaFont(.heading.large.medium)
                // 시안 원시값 #ECECEC — 대응 토큰이 없어 Label.strong으로 근사. 디자이너 검수로 확정한다
                .foregroundStyle(CHALLAColor.Label.strong)
                .multilineTextAlignment(.center)
                // SUIT의 실제 행높이가 폰트 크기보다 커서, 세로 압축을 허용하면 2줄이 1줄로 잘린다
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metric.titleTopSpacing)
        }
        // TabView 페이지는 콘텐츠를 세로 중앙에 두므로 시안처럼 위 기준으로 고정한다
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 인디케이터

    private var pageIndicator: some View {
        HStack(spacing: Metric.dotSpacing) {
            ForEach(Self.pages.indices, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentPage
                            ? CHALLAColor.Primary.yellow
                            : CHALLAColor.Label.disabled
                    )
                    .frame(width: Metric.dotSize, height: Metric.dotSize)
            }
        }
        // 점 5개를 개별 요소로 읽으면 소음만 된다 — 페이지 내용은 타이틀 텍스트로 전달된다
        .accessibilityHidden(true)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// 이미지 에셋 비율 — 시안 contents 영역 390×442.
    static let imageAspectRatio: CGFloat = 442.0 / 390.0

    /// 시안 간격 36에서 타이틀 글자 상자 위 여백(lineBoxInset)을 덜어낸 값.
    static let titleTopSpacing: CGFloat = 36 - CHALLATypography.heading.large.medium.lineBoxInset

    /// 시안 타이틀 상자(2줄 × 행간 36 = 72) 밑선에서 인디케이터까지 26.
    /// 코드의 상자는 여유분만큼 더 크므로 그만큼 되빼서 시안 간격을 유지한다.
    static let indicatorTopSpacing: CGFloat = 26 - (titleBoxHeight - 72)

    static let dotSize: CGFloat = 10
    static let dotSpacing: CGFloat = 8

    /// 타이틀 상자 높이 — 시안 2줄 × 행간 36 = 72에, SUIT 실제 행높이 초과분 여유를 더한 값.
    /// 부족하면 페이지가 세로 중앙으로 밀리며 텍스트가 잘린다 (`fixedSize` 주석 참고).
    static let titleBoxHeight: CGFloat = 88
}

#Preview {
    struct Host: View {
        @State var page = 0
        var body: some View {
            ZStack {
                CHALLAColor.Background.surface.ignoresSafeArea()
                LoginOnboardingPagerView(currentPage: $page)
            }
        }
    }
    return Host()
}
