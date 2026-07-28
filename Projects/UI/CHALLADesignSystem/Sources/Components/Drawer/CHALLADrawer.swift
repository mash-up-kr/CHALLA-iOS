import SwiftUI

/// 화면 하단에 떠 있는 드로어의 레이아웃 뷰.
/// 생김새만 담당한다 — 뜨고 내려가는 동작(딤·애니메이션·드래그)은 프레젠테이션 모디파이어 담당.
///
/// 구조: 헤더(핸들 또는 타이틀 바) → 콘텐츠 슬롯(선택) → 버튼 스택(0~2개 + 보조 액션)
///
/// ```swift
/// CHALLADrawer(
///     header: .title("방 만들기", onClose: { store.send(.closeTapped) }),
///     actions: [CHALLADrawerAction("만들기", isEnabled: canCreate) { store.send(.createTapped) }]
/// ) {
///     CHALLATextField(text: $roomName, placeholder: "방 이름 입력")
/// }
/// ```
public struct CHALLADrawer<Content: View>: View {

    /// 드로어 상단 모양.
    public enum Header {
        /// 손잡이 막대 — 끌어서 닫는 가벼운 드로어 (선택지 목록·확인 안내)
        case handle
        /// 타이틀 + 닫기 버튼 — 명시적으로 닫는 드로어 (입력이 있는 화면)
        case title(String, onClose: () -> Void)
    }

    private let header: Header
    private let actions: [CHALLADrawerAction]
    private let auxiliaryAction: CHALLADrawerAction?
    private let content: Content
    private let hasContent: Bool

    /// - Parameters:
    ///   - actions: 메인 버튼 0~2개. 배열 순서 = 위→아래 순서.
    ///   - auxiliaryAction: 맨 아래 텍스트형 버튼. variant는 무시되고 항상 투명(transparent)으로 그린다.
    public init(
        header: Header,
        actions: [CHALLADrawerAction] = [],
        auxiliaryAction: CHALLADrawerAction? = nil,
        @ViewBuilder content: () -> Content
    ) {
        assert(actions.count <= 2, "드로어 메인 버튼은 최대 2개 (Figma buttonCount 규칙)")
        self.header = header
        self.actions = actions
        self.auxiliaryAction = auxiliaryAction
        self.content = content()
        self.hasContent = Content.self != EmptyView.self
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            if hasContent {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, hasButtons ? 0 : 24)
            }
            if hasButtons {
                buttonStack
                    .padding(.top, buttonStackTopPadding)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, DrawerMetric.horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: DrawerMetric.cornerRadius)
                .fill(CHALLAColor.Background.level1)
        )
    }

    // MARK: - 구역별 뷰

    @ViewBuilder
    private var headerView: some View {
        switch header {
        case .handle:
            Capsule()
                .fill(CHALLAColor.Fill.drawerHandle)
                .frame(width: DrawerMetric.handleWidth, height: DrawerMetric.handleHeight)
                .frame(maxWidth: .infinity, minHeight: DrawerMetric.handleAreaHeight, alignment: .bottom)
                .accessibilityHidden(true) // 장식 — 끌기 동작은 프레젠테이션 모디파이어가 제공

        case let .title(title, onClose):
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(title)
                        .challaFont(.body.large.bold)
                        .foregroundStyle(CHALLAColor.Label.normal)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Button(action: onClose) {
                        CHALLAIcon.close.image(size: .size24, color: CHALLAColor.Label.normal)
                            .frame(width: DrawerMetric.closeTouchSize, height: DrawerMetric.closeTouchSize)
                            .contentShape(Rectangle().expandedToHitTarget(from: DrawerMetric.closeTouchSize))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                }
                .padding(.top, 16)
                .padding(.bottom, 8)

                Rectangle()
                    .fill(CHALLAColor.Line.neutral)
                    .frame(height: 1)
            }
        }
    }

    private var hasButtons: Bool {
        !actions.isEmpty || auxiliaryAction != nil
    }

    /// 버튼 스택 위 간격: 콘텐츠가 있으면 24, 없으면 핸들에서 24, 타이틀 구분선에서 8 (Figma 실측).
    private var buttonStackTopPadding: CGFloat {
        if hasContent {
            return 24
        }
        switch header {
        case .handle: return 24
        case .title: return 8
        }
    }

    private var buttonStack: some View {
        VStack(spacing: 8) {
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                CHALLATextButton(
                    action.title,
                    variant: action.variant,
                    role: action.role,
                    size: .large,
                    isFullWidth: true,
                    action: action.action
                )
                .disabled(!action.isEnabled)
            }
            if let auxiliaryAction {
                CHALLATextButton(
                    auxiliaryAction.title,
                    variant: .transparent,
                    role: auxiliaryAction.role,
                    size: .medium,
                    isFullWidth: true,
                    action: auxiliaryAction.action
                )
                .disabled(!auxiliaryAction.isEnabled)
            }
        }
    }
}

/// Figma Drawer 실측값. 코너 32는 드로어 전용이라 공용 CHALLARadius에 넣지 않는다.
/// 제네릭 타입(CHALLADrawer<Content>) 안에는 static 저장 프로퍼티를 둘 수 없어 파일 레벨에 둔다.
private enum DrawerMetric {
    static let cornerRadius: CGFloat = 32
    static let horizontalPadding: CGFloat = 16
    static let handleWidth: CGFloat = 52
    static let handleHeight: CGFloat = 4
    static let handleAreaHeight: CGFloat = 16
    static let closeTouchSize: CGFloat = 40
}

// MARK: - 콘텐츠 없는 드로어

public extension CHALLADrawer where Content == EmptyView {
    /// 콘텐츠 슬롯 없이 버튼만 있는 드로어 (예: 앨범에서 선택 / 프로필 사진 삭제).
    init(
        header: Header,
        actions: [CHALLADrawerAction] = [],
        auxiliaryAction: CHALLADrawerAction? = nil
    ) {
        self.init(header: header, actions: actions, auxiliaryAction: auxiliaryAction) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 20) {
        CHALLADrawer(
            header: .handle,
            actions: [
                CHALLADrawerAction("앨범에서 선택", variant: .neutral) {},
                CHALLADrawerAction("프로필 사진 삭제", variant: .neutral, role: .destructive) {}
            ],
            auxiliaryAction: CHALLADrawerAction("보조 액션") {}
        )
        CHALLADrawer(
            header: .title("방 만들기", onClose: {}),
            actions: [CHALLADrawerAction("만들기", isEnabled: false) {}]
        ) {
            Text("콘텐츠 슬롯")
                .challaFont(.body.medium.medium)
                .foregroundStyle(CHALLAColor.Label.neutral)
        }
    }
    .padding(12)
    .frame(maxHeight: .infinity)
    .background(CHALLAColor.Background.surface)
}
