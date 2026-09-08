import CHALLADesignSystem
import SwiftUI
import UIKit

/// ZStack 화면 교체 위에서 UINavigationController push/pop과 모달 present/dismiss를 재현하는 전환 계산기.
///
/// SwiftUI는 제거되는 뷰의 `.transition` 값을 그 뷰가 마지막으로 렌더된 시점 것으로 고정한다.
/// 그래서 "방 상세"처럼 상황 따라 나가는 방향이 다른 화면(홈으로 pop = 오른쪽으로 퇴장,
/// 사진 상세 push = 왼쪽으로 밀림, 카메라 present = 제자리)은 정적 transition으로 표현할 수 없다.
/// 대신 참조 타입인 이 코디네이터에 현재 전이(from→to)를 기록해 두고,
/// `ScreenTransitionModifier`가 애니메이션 프레임마다 이를 읽어 방향을 결정한다.
///
@MainActor
final class ScreenTransitionCoordinator {

    enum Kind {
        case push, pop, present, dismiss
        /// 네비게이션 관계가 아닌 화면 교체(로그인↔홈 등) — 페이드.
        case replace
    }

    private(set) var kind: Kind = .replace
    private(set) var from: AppFeature.State.ScreenID = .launching
    private(set) var to: AppFeature.State.ScreenID = .launching
    var containerSize: CGSize = .zero
    /// 상태바 높이. 세로 전환 때 상태바 띠를 페이드로 덮는 데 쓴다.
    var topInset: CGFloat = 0

    /// 화면 전환 속도. 앱 안의 모든 push/pop·present/dismiss가 이 값 하나를 공유한다.
    ///
    /// 설정 내부 `NavigationStack`의 네이티브 전환에 맞춘 값이다
    static let transitionAnimation: Animation = .smooth(duration: 0.25)

    /// 이번 화면 교체에 쓸 애니메이션. 제스처가 이미 화면을 밀어낸 뒤의 상태 반영은 nil이 된다.
    private(set) var animation: Animation? = ScreenTransitionCoordinator.transitionAnimation
    private var skipNextAnimation = false

    /// 인터랙티브 pop 중 밑에 깔 부모 화면 스냅샷. 화면 ID를 키로 보관한다.
    private var parentSnapshots: [AppFeature.State.ScreenID: UIImage] = [:]

    func update(to newID: AppFeature.State.ScreenID) {
        guard newID != to else { return }
        from = to
        to = newID
        kind = Self.classify(from: from, to: to)
        animation = skipNextAnimation ? nil : Self.transitionAnimation
        skipNextAnimation = false
    }

    /// 지금 화면이 정지 상태일 때 호출해 `id` 화면의 스냅샷을 보관한다.
    func captureSnapshot(for id: AppFeature.State.ScreenID) {
        guard let image = Self.snapshotKeyWindow() else { return }
        parentSnapshots[id] = image
    }

    /// 다음 상태 반영을 애니메이션 없이 수행한다 — 제스처가 화면을 이미 끝까지 밀어낸 경우.
    func completeInteractivePop() {
        skipNextAnimation = true
    }

    /// `id` 화면을 엣지 스와이프로 걷어냈을 때 드러날 부모 화면의 스냅샷. 없으면 제스처를 막는다.
    func snapshotBehind(_ id: AppFeature.State.ScreenID) -> UIImage? {
        Self.popParent(of: id).flatMap { parentSnapshots[$0] }
    }

    /// ZStack 전환 중 겹치는 두 화면의 위아래. SwiftUI는 삽입되는 뷰를 위에 두므로,
    /// pop에서 밀려나는 자식이 부모에 덮이지 않으려면 깊은 화면이 항상 위라고 못 박아야 한다.
    static func zIndex(of id: AppFeature.State.ScreenID) -> Double {
        switch id {
        case .roomDetail, .setting: return 1
        case .photoDetail, .chat, .profileEdit, .roomSettings: return 2
        case .camera: return 3
        default: return 0
        }
    }

    static func popParent(of id: AppFeature.State.ScreenID) -> AppFeature.State.ScreenID? {
        switch id {
        case .roomDetail, .setting: return .home
        case .photoDetail, .chat, .roomSettings: return .roomDetail
        case .profileEdit: return .setting
        default: return nil
        }
    }

    /// pop으로 이 화면이 드러날 수 있어 스냅샷을 남겨둘 화면인지.
    static func isPopParent(_ id: AppFeature.State.ScreenID) -> Bool {
        switch id {
        case .home, .roomDetail, .setting: return true
        default: return false
        }
    }

    private static func snapshotKeyWindow() -> UIImage? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return nil }
        return UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    /// 전환 중 각 화면이 놓일 위치. `progress` 0 = 제자리, 1 = 전환 끝점(화면 밖).
    func placement(for id: AppFeature.State.ScreenID, progress: CGFloat) -> Placement {
        // 스프링 오버슛이 0…1을 벗어나면 화면이 제자리를 지나쳐 뒤 여백이 비친다.
        let progress = min(max(progress, 0), 1)
        guard progress > 0, id == from || id == to else { return Placement() }

        switch kind {
        case .replace:
            return Placement(opacity: 1 - progress)

        case .push, .pop:
            // 위에 얹혀 화면 폭만큼 움직이는 쪽은 항상 더 깊은 화면이다.
            let top = kind == .push ? to : from
            if id == top {
                return Placement(offsetX: progress * containerSize.width)
            }
            // 아래 화면은 UIKit처럼 폭의 30%만 밀리며 살짝 어두워진다.
            return Placement(offsetX: -progress * containerSize.width * 0.3, dim: 0.1 * progress)

        case .present, .dismiss:
            let covering = kind == .present ? to : from
            if id == covering {
                // 상태바 띠는 세로 이동 경로의 맨 끝이라 스프링 꼬리에서야 덮인다 —
                // 위치와 무관하게 진행도에 맞춰 페이드로 덮어 색 경계를 없앤다.
                return Placement(offsetY: progress * containerSize.height, statusCover: 1 - progress)
            }
            // 배경 화면은 모달이 덮는 동안 제자리에 그대로 남는다.
            return Placement()
        }
    }

    struct Placement {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var opacity: Double = 1
        var dim: Double = 0
        /// 상태바 띠를 덮는 검정의 불투명도 (세로 전환의 covering 화면에만 쓰인다).
        var statusCover: Double = 0
    }

    /// 화면 관계 분류. 네비게이션 트리는 홈(0) → 방 상세·설정(1) → 사진 상세·채팅·프로필 편집(2),
    /// 카메라는 어디서 열려도 모달이다.
    private static func classify(
        from: AppFeature.State.ScreenID,
        to: AppFeature.State.ScreenID
    ) -> Kind {
        if to == .camera {
            return .present
        }
        if from == .camera {
            return .dismiss
        }
        guard let fromDepth = navigationDepth(from), let toDepth = navigationDepth(to) else {
            return .replace
        }
        if toDepth > fromDepth {
            return .push
        }
        if toDepth < fromDepth {
            return .pop
        }
        return .replace
    }

    private static func navigationDepth(_ id: AppFeature.State.ScreenID) -> Int? {
        switch id {
        case .home: return 0
        case .roomDetail, .setting: return 1
        case .photoDetail, .chat, .profileEdit, .roomSettings: return 2
        default: return nil
        }
    }
}

/// 화면 하나에 붙는 전환 modifier. 오프셋을 값으로 갖지 않고 코디네이터에서 매 프레임 읽는다 —
/// 그래야 제거 시점의 실제 전이 방향(push였는지 pop이었는지)이 반영된다.
struct ScreenTransitionModifier: ViewModifier, @preconcurrency Animatable {

    var progress: CGFloat
    let id: AppFeature.State.ScreenID
    let coordinator: ScreenTransitionCoordinator

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let placement = coordinator.placement(for: id, progress: progress)
        content
            .offset(x: placement.offsetX, y: placement.offsetY)
            .opacity(placement.opacity)
            .overlay(alignment: .top) {
                if placement.statusCover > 0 {
                    CHALLAColor.Static.black
                        .frame(height: coordinator.topInset)
                        .offset(y: -coordinator.topInset)
                        .opacity(placement.statusCover)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                Color.black
                    .opacity(placement.dim)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
    }
}

extension AnyTransition {

    static func screen(
        _ id: AppFeature.State.ScreenID,
        coordinator: ScreenTransitionCoordinator
    ) -> AnyTransition {
        .modifier(
            active: ScreenTransitionModifier(progress: 1, id: id, coordinator: coordinator),
            identity: ScreenTransitionModifier(progress: 0, id: id, coordinator: coordinator)
        )
    }
}

extension View {

    /// AppView 화면 브랜치 공통 장식 — 방향 인지 전환 + 스택 깊이 zIndex.
    func screenLayer(
        _ id: AppFeature.State.ScreenID,
        coordinator: ScreenTransitionCoordinator
    ) -> some View {
        transition(.screen(id, coordinator: coordinator))
            .zIndex(ScreenTransitionCoordinator.zIndex(of: id))
    }
}
