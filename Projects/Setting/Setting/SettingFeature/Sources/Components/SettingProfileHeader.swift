import CHALLADesignSystem
import SettingDomain
import SwiftUI

/// 설정 화면 맨 위의 프로필 블록 — 아바타 + 닉네임/이메일 + 편집 버튼.
///
/// 디자인 시스템에 올리지 않고 이 피처 안에 두는 이유:
/// 지금 쓰이는 곳이 설정 화면 하나뿐이라서다. DS에 넣으면 검수앱 갤러리에
/// Variant를 나열할 의무가 따라붙는데(`.claude/rules/design-system.md`),
/// 재사용처가 하나면 그 비용을 치를 근거가 없다.
/// 다른 화면에서도 같은 블록이 필요해지면 그때 승격한다.
struct SettingProfileHeader: View {

    /// `nil`이면 아직 불러오는 중 — 자리만 잡아 화면이 덜컥거리지 않게 한다.
    let profile: SettingProfile?

    let onEditTapped: () -> Void

    var body: some View {
        // 내용 줄(68)을 블록(100) 안에서 위쪽에 붙인다 — 시안의 아바타는 세로 중앙이 아니라 위에서 8이다.
        // 줄 높이를 68로 고정하면 세로 중앙 정렬만으로 나머지도 시안과 맞는다:
        // 아바타 68 → 오프셋 8, 텍스트 44 → 8+12=20(시안 y134), 편집 버튼 54 → 8+7=15(시안 y129).
        HStack(spacing: 0) {
            avatar
            texts
                .padding(.leading, Metric.avatarToTextSpacing)
            Spacer(minLength: 0)
            editButton
        }
        .frame(height: Metric.contentRowHeight)
        .padding(.leading, Metric.leadingPadding)
        .padding(.trailing, Metric.trailingPadding)
        .padding(.top, Metric.contentTopInset)
        .padding(.bottom, Metric.blockHeight - Metric.contentTopInset - Metric.contentRowHeight)
    }

    // MARK: - 아바타

    /// 프로필 사진이 없을 때는 시안의 기본 아바타(회색 원 + 실루엣)를 그린다.
    /// 사진이 있을 때의 로딩은 이미지 모듈(#25 `CHALLAImageKit`)이 들어온 뒤에 붙인다.
    private var avatar: some View {
        Circle()
            .fill(Metric.avatarBackground)
            .frame(width: Metric.avatarSize, height: Metric.avatarSize)
            .overlay {
                CHALLAIcon.profile.image(
                    size: .size32,
                    color: Metric.avatarSilhouette
                )
            }
            .accessibilityHidden(true) // 닉네임이 바로 옆에서 읽히므로 중복 낭독을 막는다
    }

    // MARK: - 닉네임 · 이메일

    private var texts: some View {
        VStack(alignment: .leading, spacing: Metric.nicknameToEmailSpacing) {
            Text(profile?.nickname ?? "")
                .challaFont(.body.medium.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
                .lineLimit(1)
            Text(profile?.email ?? "")
                .challaFont(.body.medium.regular)
                .foregroundStyle(CHALLAColor.Label.alternative)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 편집 버튼

    /// 시안의 터치 영역은 54×54로 HIG 최소치(44)를 넘는다 — 그대로 쓴다.
    private var editButton: some View {
        Button(action: onEditTapped) {
            CHALLAIcon.pencilSimple.image(
                size: .size24,
                color: CHALLAColor.Label.alternative
            )
            .frame(width: Metric.editTouchArea, height: Metric.editTouchArea)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 편집")
    }
}

// MARK: - Metric

private enum Metric {
    /// 시안 실측 — 프로필 블록 390×100.
    static let blockHeight: CGFloat = 100
    /// 블록 안의 내용 줄 높이 = 아바타 높이. 시안에서 아바타·텍스트·편집 버튼이 이 줄에 세로 중앙 정렬된다.
    static let contentRowHeight: CGFloat = 68
    /// 블록 위에서 내용 줄까지의 여백 (시안 아바타 y122 − 블록 y114).
    static let contentTopInset: CGFloat = 8
    static let avatarSize: CGFloat = 68
    /// 아바타 왼쪽 여백. 카드(16)보다 넓다 — 시안 실측값.
    static let leadingPadding: CGFloat = 28
    /// 편집 버튼 터치 영역 오른쪽 여백.
    static let trailingPadding: CGFloat = 20
    static let avatarToTextSpacing: CGFloat = 16
    /// 닉네임과 이메일 사이. 시안 간격은 4지만 그대로 주면 안 된다 —
    /// `challaFont`가 두 글자 상자에 각각 위아래 여백(`lineBoxInset`)을 더하므로 그만큼 빼야
    /// 화면에서 4로 보인다 (`CHALLAListRow`의 제목–설명 간격과 같은 보정).
    static let nicknameToEmailSpacing: CGFloat = max(
        0,
        4 - CHALLATypography.body.medium.bold.lineBoxInset
            - CHALLATypography.body.medium.regular.lineBoxInset
    )
    static let editTouchArea: CGFloat = 54

    /// 기본 아바타 색 — 시안 실측 `#242424` 원 + `#3B3B3B` 실루엣이 각각 토큰과 일치한다.
    static let avatarBackground = CHALLAColor.Background.level2
    static let avatarSilhouette = CHALLAColor.Background.level4
}
