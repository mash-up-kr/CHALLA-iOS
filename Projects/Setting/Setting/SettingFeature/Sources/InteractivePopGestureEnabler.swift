import SwiftUI
import UIKit

/// 네비게이션 바를 숨긴 `NavigationStack`에서 비활성화되는 스와이프 백 제스처를 복구한다.
///
/// 하위 화면이 `CHALLATopNavigation`을 직접 그리기 위해 `toolbar(.hidden, for: .navigationBar)`를
/// 적용하면, UIKit이 `interactivePopGestureRecognizer`의 시작을 막아 제스처가 동작하지 않는다.
/// SwiftUI에는 이 동작을 제어하는 API가 없어 `UINavigationController`에 직접 접근한다.
///
/// `NavigationStack`의 루트 뷰에 한 번만 적용한다 — 스택 전체가 하나의 컨트롤러를 공유하므로
/// 이후 push되는 화면에도 그대로 적용된다.
struct InteractivePopGestureEnabler: UIViewControllerRepresentable {

    func makeUIViewController(context _: Context) -> PopGestureEnablingController {
        PopGestureEnablingController()
    }

    func updateUIViewController(_: PopGestureEnablingController, context _: Context) {}
}

/// 제스처 `delegate` 역할만 담당하는 빈 컨트롤러.
///
/// 루트 화면에서 제스처가 시작되면 pop할 대상이 없어 네비게이션이 멈추므로,
/// 스택에 화면이 쌓여 있을 때만 제스처를 허용한다.
final class PopGestureEnablingController: UIViewController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 터치를 가로채지 않는다 — 제스처 설정 외에는 화면에 관여하지 않는다.
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableInteractivePop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 뷰 계층에 편입되는 시점이 상황에 따라 달라 두 시점 모두에서 설정한다.
        enableInteractivePop()
    }

    private func enableInteractivePop() {
        guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
        gesture.isEnabled = true
        gesture.delegate = self
    }

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}
