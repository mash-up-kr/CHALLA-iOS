import SwiftUI

/// 드로어 콘텐츠 슬롯에 넣는 제목+설명 텍스트 블록 (예: 회원 탈퇴 확인·완료 안내).
/// 이 패턴이 여러 화면에서 반복되므로 각 화면이 서체·색을 직접 만지지 않게 공용화한다.
///
/// ```swift
/// CHALLADrawer(header: .handle, actions: [...]) {
///     CHALLADrawerMessage("모든 기록이 사라져요", description: "탈퇴 시 참여 중이던 방에서 나가져요")
/// }
/// ```
public struct CHALLADrawerMessage: View {
    private let title: String
    private let description: String?

    public init(_ title: String, description: String? = nil) {
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .challaFont(.heading.xsmall.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
            if let description {
                Text(description)
                    .challaFont(.body.medium.regular)
                    .foregroundStyle(CHALLAColor.Label.alternative)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 8) // Figma 실측: 블록 자체 여백 (위 8 · 아래 4)
        .padding(.bottom, 4)
    }
}

#Preview {
    CHALLADrawer(
        header: .handle,
        actions: [CHALLADrawerAction("그래도 탈퇴하기", role: .destructive) {}],
        auxiliaryAction: CHALLADrawerAction("닫기") {}
    ) {
        CHALLADrawerMessage("모든 기록이 사라져요", description: "탈퇴 시 참여 중이던 방에서 나가져요")
    }
    .padding(12)
    .background(CHALLAColor.Background.surface)
}
