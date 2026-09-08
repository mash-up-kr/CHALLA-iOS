import SwiftUI
import UIKit

/// 시스템 공유 시트(`UIActivityViewController`)의 SwiftUI 래퍼.
/// `ShareLink`는 자기 버튼으로만 열 수 있어, 디자인 시스템 콜백 → 리듀서 → State로 여는
/// 이 화면에서는 컨트롤러를 직접 감싼다. 다른 화면이 쓰게 되면 공용 모듈로 승격한다.
struct ActivityShareSheet: UIViewControllerRepresentable {

    let items: [Any]
    /// 공유를 마치거나 취소했을 때 — 호출부가 시트 열림 상태를 내린다.
    /// 컨트롤러는 자기 자신을 닫으려 하는데 실제로 떠 있는 것은 SwiftUI 시트라,
    /// 여기서 알려주지 않으면 기기에 따라 빈 시트가 남는다.
    let onComplete: () -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
