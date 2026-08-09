import CHALLADesignSystem
import SwiftUI

// TODO: CHALLAAvatar 활용 여지 검토
/// 프로필 아바타 (80pt 원) + 카메라 배지.
/// 탭 영역은 원 전체다 — 배지(32pt)만 탭 대상으로 삼으면 HIG 최소 터치 타깃(44pt) 미만이다.
struct ProfileAvatarView: View {

    let source: ProfileAvatarSource
    let showsCameraBadge: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            avatarCircle
                .overlay(alignment: .topLeading) {
                    if showsCameraBadge {
                        cameraBadge
                            .offset(x: Metric.badgeOffset, y: Metric.badgeOffset)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 사진 선택")
    }

    @ViewBuilder
    private var avatarCircle: some View {
        switch source {
        case .placeholder:
            placeholderSilhouette
        case let .local(data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Metric.diameter, height: Metric.diameter)
                    .clipShape(Circle())
            } else {
                placeholderSilhouette
            }
        case let .remote(url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(CHALLAColor.Background.level2)
            }
            .frame(width: Metric.diameter, height: Metric.diameter)
            .clipShape(Circle())
        }
    }

    private var placeholderSilhouette: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(CHALLAColor.Background.level2)
            Circle()
                .fill(CHALLAColor.Background.level4)
                .frame(width: Metric.headDiameter, height: Metric.headDiameter)
                .offset(y: Metric.headTop)
            Ellipse()
                .fill(CHALLAColor.Background.level4)
                .frame(width: Metric.torsoWidth, height: Metric.torsoHeight)
                .offset(y: Metric.torsoTop)
        }
        .frame(width: Metric.diameter, height: Metric.diameter)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var cameraBadge: some View {
        Circle()
            .fill(CHALLAColor.Background.level2)
            .frame(width: Metric.badgeDiameter, height: Metric.badgeDiameter)
            .overlay {
                CHALLAIcon.camera.image(size: .size18, color: CHALLAColor.Label.alternative)
            }
            // 레이어 데이터에 stroke가 없어 관찰 기반으로 카드색 1pt를 두른다 (§10-7, 디자이너 확인 대기).
            .overlay {
                Circle().strokeBorder(CHALLAColor.Background.level1, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Zeplin 실측값

private enum Metric {
    static let diameter: CGFloat = 80
    static let headDiameter: CGFloat = 29.6
    static let headTop: CGFloat = 13.6
    static let torsoWidth: CGFloat = 62.4
    static let torsoHeight: CGFloat = 32
    static let torsoTop: CGFloat = 48
    static let badgeDiameter: CGFloat = 32
    /// 아바타 좌상단 기준 배지 좌상단 위치 (x = y).
    static let badgeOffset: CGFloat = 54
}

#Preview {
    HStack(spacing: 24) {
        ProfileAvatarView(source: .placeholder, showsCameraBadge: true) {}
        ProfileAvatarView(source: .placeholder, showsCameraBadge: false) {}
    }
    .padding(40)
    .background(CHALLAColor.Background.level1)
}
