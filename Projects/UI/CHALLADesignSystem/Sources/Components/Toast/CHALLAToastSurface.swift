import SwiftUI

/// 토스트의 표면(배경·여백·최대 너비)만 담당한다. 안에 무엇을 그릴지는 담는 쪽이 정한다.
///
/// 문구 일부만 말줄임해야 하거나(방 이름) 앞에 프로필 사진을 두어야 해서
/// 단일 `String`으로 표현할 수 없는 토스트가 이 표면을 쓴다.
/// 글자만 있는 흔한 경우는 `CHALLAToast`가 이 표면을 감싼 것이다.
public struct CHALLAToastSurface<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(minHeight: CHALLAToastMetric.contentMinHeight)
            .padding(.horizontal, CHALLAToastMetric.horizontalPadding)
            .padding(.vertical, CHALLAToastMetric.verticalPadding)
            // 내용만큼만 넓어지고 한도에서 멈춘다 — maxWidth만 걸면 항상 한도까지 늘어난다.
            .frame(maxWidth: CHALLAToastMetric.maxWidth)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                RoundedRectangle(cornerRadius: CHALLARadius.large)
                    // 시안의 background blur(radius 12)에 대응하는 SwiftUI 재질.
                    .fill(CHALLAColor.Background.level1.opacity(CHALLAToastMetric.backgroundOpacity))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: CHALLARadius.large)
                    )
            }
    }
}

// MARK: - Zeplin 실측값

public enum CHALLAToastMetric {
    static let contentMinHeight: CGFloat = 32
    public static let contentSpacing: CGFloat = 8
    static let maxWidth: CGFloat = 320

    /// 여백·배경 농도는 스낵바와 같은 표면 값을 쓴다 (`CHALLAFloatingSurface`).
    /// 배경에 재질을 한 겹 더 까는 것만 달라서 모디파이어 대신 상수만 공유한다.
    static let horizontalPadding = CHALLAFloatingSurfaceMetric.horizontalPadding
    static let verticalPadding = CHALLAFloatingSurfaceMetric.verticalPadding
    static let backgroundOpacity = CHALLAFloatingSurfaceMetric.backgroundOpacity

    /// 프로필 사진이 붙는 변형의 아바타 지름.
    /// TODO: 시안 대조 전 임시값 — 본문 22pt 아바타(채팅 메시지)와 같은 값을 썼다.
    public static let avatarSize: CGFloat = 22
}
