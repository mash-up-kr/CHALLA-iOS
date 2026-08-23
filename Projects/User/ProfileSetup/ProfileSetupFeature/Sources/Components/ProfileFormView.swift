import CHALLADesignSystem
import SwiftUI

/// 프로필 폼 (헤드라인 + 카드 + CTA) — store를 모르는 파라미터 뷰.
/// 다른 화면이 같은 폼을 필요로 하면 공유 모듈로 뺄 수 있게 UserDomain도 참조하지 않는다.
///
/// 세로 배치: 콘텐츠 블록은 내비 하단 ~ CTA 슬롯 상단의 정중앙이고,
/// CTA 슬롯(위 여백 8 + 높이 54)은 버튼이 없어도 자리를 예약한다 — CTA 등장 시 카드가 움직이지 않는다.
struct ProfileFormView: View {

    @Environment(\.challaTheme) private var theme

    let headline: ProfileFormHeadline
    let avatar: ProfileAvatarSource
    let showsCameraBadge: Bool
    @Binding var nickname: String
    var focus: FocusState<Bool>.Binding
    let fieldMode: ProfileNicknameFieldMode
    let cta: ProfileFormCTA?
    let onAvatarTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 키보드가 올라오면 작은 화면(SE)에선 콘텐츠가 남는 높이를 넘겨 CTA가 화면 밖으로 밀린다.
            // minHeight로 여유가 있을 때의 중앙 정렬은 지키고, 모자랄 때만 이 영역이 스크롤되게 한다.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        headlineView
                        card
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.never) // 스크롤로 포커스가 풀리면 CTA가 다시 아래로 내려간다
                // 넘칠 때 잘리는 쪽은 장식인 헤드라인이어야 한다 — 입력 카드는 온전히 보여야 한다.
                .defaultScrollAnchor(.bottom)
            }
            ctaSlot
        }
    }

    /// 두 줄 고정(줄당 lh30 = 텍스트 60) — 환영 상태에서도 높이가 변하지 않는다.
    private var headlineView: some View {
        VStack(spacing: 0) {
            if let highlighted = headline.highlighted {
                Text(highlighted)
                    .challaFont(.heading.small.bold)
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)
            }
            Text(headline.text)
                .challaFont(.heading.small.bold)
                .foregroundStyle(CHALLAColor.Label.normal)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, Metric.headlineVerticalPadding)
    }

    private var card: some View {
        VStack(spacing: Metric.avatarToField) {
            ProfileAvatarView(
                source: avatar,
                showsCameraBadge: showsCameraBadge,
                onTap: onAvatarTap
            )
            ProfileNicknameField(nickname: $nickname, focus: focus, mode: fieldMode)
        }
        .padding(.horizontal, Metric.cardInnerHorizontal)
        .padding(.vertical, Metric.cardInnerVertical)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.xlarge)
                .fill(CHALLAColor.Background.level1)
        }
        .padding(.horizontal, Metric.cardMargin)
    }

    private var ctaSlot: some View {
        Group {
            if let cta {
                if cta.isLoading {
                    ctaButton(cta)
                        .accessibilityValue("저장 중")
                } else {
                    ctaButton(cta)
                }
            } else {
                Color.clear.frame(height: Metric.ctaHeight)
            }
        }
        .padding(.horizontal, Metric.ctaMargin)
        .padding(.top, Metric.ctaTopSpacing)
        // 키보드가 열리면(≈ 포커스) 키보드 위 16, 없으면 홈 인디케이터 세이프에어리어 바로 위(0).
        .padding(.bottom, focus.wrappedValue ? Metric.ctaKeyboardSpacing : 0)
    }

    private func ctaButton(_ cta: ProfileFormCTA) -> some View {
        CHALLATextButton(cta.title, isFullWidth: true, isLoading: cta.isLoading, action: cta.action)
            // 로딩 중엔 disabled를 걸지 않는다 — 시안(d237)은 활성 배경색 유지, 터치는 isLoading이 차단.
            .disabled(!cta.isEnabled && !cta.isLoading)
    }
}

// MARK: - Zeplin 실측값 (390x844 기준)

private enum Metric {
    static let headlineVerticalPadding: CGFloat = 24
    /// 카드 좌우 마진 32 → 폭 326.
    static let cardMargin: CGFloat = 32
    static let cardInnerHorizontal: CGFloat = 24
    /// 상하 28 + 아바타 80 + 간격 20 + 필드 52 = 카드 높이 208.
    static let cardInnerVertical: CGFloat = 28
    static let avatarToField: CGFloat = 20
    static let ctaMargin: CGFloat = 16
    static let ctaTopSpacing: CGFloat = 8
    /// CHALLATextButton large 높이 — 슬롯 자리 예약용.
    static let ctaHeight: CGFloat = 54
    static let ctaKeyboardSpacing: CGFloat = 16
}

#Preview {
    @Previewable @State var nickname = "나는야멋쟁이토마토"
    @Previewable @FocusState var focus: Bool

    ZStack {
        CHALLAColor.Background.surface.ignoresSafeArea()
        ProfileFormView(
            headline: ProfileFormHeadline(highlighted: nil, text: "프로필과 닉네임을\n설정해 주세요"),
            avatar: .placeholder,
            showsCameraBadge: true,
            nickname: $nickname,
            focus: $focus,
            fieldMode: .editable,
            cta: ProfileFormCTA(title: "시작하기", isEnabled: true, isLoading: false) {},
            onAvatarTap: {}
        )
    }
}
