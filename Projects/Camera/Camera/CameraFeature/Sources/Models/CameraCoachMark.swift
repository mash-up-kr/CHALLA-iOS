import Foundation

/// 카메라 화면에 처음 들어왔을 때 셔터 사용법을 알려주는 스낵바 단계.
/// 액션을 누르면 `next`로 넘어가고, `next`가 없으면 스낵바가 사라진다.
public enum CameraCoachMark: String, Equatable, Sendable, CaseIterable {

    case shutterCost
    case shutterCaution

    public var message: String {
        switch self {
        case .shutterCost: "셔터를 누르는 순간 장수가 차감돼요."
        case .shutterCaution: "신중하게 셔터를 눌러 보세요."
        }
    }

    public var actionTitle: String {
        switch self {
        case .shutterCost: "다음"
        case .shutterCaution: "확인"
        }
    }

    var next: CameraCoachMark? {
        switch self {
        case .shutterCost: .shutterCaution
        case .shutterCaution: nil
        }
    }

    static let first = CameraCoachMark.shutterCost

    /// 화면 진입 후 첫 단계가 뜨기까지의 지연.
    static let presentationDelay: Duration = .milliseconds(500)
}
