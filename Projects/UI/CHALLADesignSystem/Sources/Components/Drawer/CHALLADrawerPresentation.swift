import SwiftUI
import UIKit // 키보드 내림(resignFirstResponder) 전용 — SwiftUI에는 대응 API가 없다

/// 드로어 프레젠테이션 — 딤 배경 위에 드로어를 띄우고 내리는 동작 전부를 담당한다.
/// (드로어의 생김새는 CHALLADrawer 담당 — 역할 분리)
///
/// 네이티브 .sheet를 쓰지 않는 이유: 시안의 드로어는 좌우·하단 12pt 여백을 두고
/// 떠 있는 카드 모양인데, 시스템 시트는 화면 가장자리에 붙는 형태라 이 모양이 안 나온다.
/// 커스텀으로 가면서 시스템이 주던 딤·등장 애니메이션·끌어서 닫기를 여기서 직접 구현한다.
struct CHALLADrawerPresentationModifier<DrawerContent: View>: ViewModifier {

    // MARK: - 프로퍼티

    @Binding var isPresented: Bool
    let allowsInteractiveDismiss: Bool
    let bottomMargin: CGFloat
    @ViewBuilder let drawerContent: () -> DrawerContent

    /// 손가락으로 끌어내린 거리. 손을 떼면 0으로 복귀하거나(제자리) 닫힌다.
    @State private var dragOffset: CGFloat = 0

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .bottom) {
                    if isPresented {
                        dim
                        drawer
                    }
                }
                .animation(DrawerPresentationMetric.spring, value: isPresented)
            }
            // 닫힐 때 키보드를 함께 내린다. 두지 않으면 퇴장 애니메이션이 끝난 뒤에야 키보드가 내려간다.
            .onChange(of: isPresented) { _, isPresented in
                guard !isPresented else { return }
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
    }

    // MARK: - 딤 · 드로어 · 닫기 제스처

    private var dim: some View {
        CHALLAColor.Material.dimmer
            .ignoresSafeArea() // 딤은 safe area 밖까지 덮는다 (드로어는 안전 영역 안)
            .transition(.opacity)
            .onTapGesture {
                // 딤 탭으로 닫기. allowsInteractiveDismiss가 false면 동작하지 않는다
                guard allowsInteractiveDismiss else { return }
                isPresented = false
            }
            .accessibilityHidden(true) // VoiceOver 초점은 드로어(.isModal)가 가져간다
    }

    private var drawer: some View {
        drawerContent()
            .padding(.horizontal, DrawerPresentationMetric.screenMargin)
            // 안전 영역 기준 여백이라 키보드가 올라오면 드로어도 자동으로 따라 올라간다
            .padding(.bottom, bottomMargin)
            .offset(y: max(0, dragOffset)) // 아래 방향 드래그만 반영한다
            .gesture(dragToDismiss) // 드로어 아무 데나 잡고 끌 수 있음
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isModal) // VoiceOver 탐색 범위를 드로어로 제한
            .onDisappear { dragOffset = 0 } // 다음 표시가 원위치에서 시작하도록 끌린 거리 초기화
    }

    private var dragToDismiss: some Gesture {
        DragGesture()
            // 끄는 동안: 드로어가 손가락을 따라옴
            .onChanged { value in
                guard allowsInteractiveDismiss else { return }
                dragOffset = value.translation.height
            }
            // 손 뗀 순간: 기준 넘게 끌었으면 닫고, 아니면 제자리로
            .onEnded { value in
                guard allowsInteractiveDismiss else { return }
                if value.translation.height > DrawerPresentationMetric.dismissThreshold {
                    isPresented = false
                } else {
                    // 복귀는 여기서 직접 애니메이션 (body의 것은 isPresented 전용)
                    withAnimation(DrawerPresentationMetric.spring) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Figma 실측값

/// 제네릭 타입(Modifier<DrawerContent>) 안에는 static 저장 프로퍼티를 둘 수 없어 파일 레벨에 둔다.
private enum DrawerPresentationMetric {
    /// 디바이스 기준 좌우·하단 여백 (Figma Drawer 명세)
    static let screenMargin: CGFloat = 12
    /// 이 거리(pt) 이상 끌어내리면 닫힘, 미만이면 제자리 복귀
    static let dismissThreshold: CGFloat = 120
    /// 등장/퇴장·드래그 복귀 공통 스프링. 실기기 검수 후 이 값 하나만 조정하면 된다.
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - challaDrawer

/// 기능은 위 Modifier에 있고, 이 extension은 다른 프레젠테이션 API(.sheet 등)처럼
/// .challaDrawer(...) 점 문법으로 쓰게 하는 통로다.
public extension View {
    /// 드로어를 화면 하단에 띄운다. 콘텐츠가 텍스트필드를 담으면 키보드에 맞춰 올라온다.
    ///
    /// - Parameters:
    ///   - allowsInteractiveDismiss: 딤 탭·아래로 끌기로 닫기 허용 여부 (기본 true).
    ///     입력 중 실수로 닫히면 안 되는 드로어(타이틀 헤더형)는 false로 두고
    ///     닫기 버튼으로만 닫는다.
    ///   - bottomMargin: 안전 영역 하단과 드로어 사이 여백. nil이면 시안 기본값(12).
    ///     뒤에 남는 화면 요소를 드로어로 덮어야 할 때만 더 작은 값을 준다.
    ///
    /// ```swift
    /// .challaDrawer(isPresented: $showsProfileMenu) {
    ///     CHALLADrawer(header: .handle, actions: [...])
    /// }
    /// ```
    func challaDrawer(
        isPresented: Binding<Bool>,
        allowsInteractiveDismiss: Bool = true,
        bottomMargin: CGFloat? = nil,
        @ViewBuilder drawer: @escaping () -> some View
    ) -> some View {
        modifier(CHALLADrawerPresentationModifier(
            isPresented: isPresented,
            allowsInteractiveDismiss: allowsInteractiveDismiss,
            bottomMargin: bottomMargin ?? DrawerPresentationMetric.screenMargin,
            drawerContent: drawer
        ))
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var isPresented = true

        var body: some View {
            VStack {
                CHALLATextButton("드로어 열기") { isPresented = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CHALLAColor.Background.surface)
            .challaDrawer(isPresented: $isPresented) {
                CHALLADrawer(
                    header: .handle,
                    actions: [
                        CHALLADrawerAction("앨범에서 선택", variant: .neutral) {},
                        CHALLADrawerAction("프로필 사진 삭제", variant: .neutral, role: .destructive) {}
                    ],
                    footerAction: CHALLADrawerAction("푸터 액션") { isPresented = false }
                )
            }
        }
    }
    return PreviewHost()
}
