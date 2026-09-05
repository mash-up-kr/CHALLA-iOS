import SwiftUI
import UIKit

/// 시스템 공유 시트(`UIActivityViewController`)의 SwiftUI 래퍼.
/// `ShareLink`는 자기 버튼으로만 열 수 있어, 디자인 시스템 콜백 → 리듀서 → State로 여는
/// 이 화면에서는 컨트롤러를 직접 감싼다. 다른 화면이 쓰게 되면 공용 모듈로 승격한다.
struct ActivityShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
