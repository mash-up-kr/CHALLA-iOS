import Foundation

/// 촬영 가능 여부. 서버 응답으로 결정되며, 막힌 사유 문구도 서버가 함께 내려주는 것을 전제로 한다.
public enum CameraCaptureAvailability: Equatable, Sendable {

    case available

    /// 촬영이 막힌 상태.
    /// - viewportMessage: 뷰파인더 자리에 대신 띄우는 안내
    /// - toastMessage: 그래도 셔터를 눌렀을 때 뜨는 토스트
    case unavailable(viewportMessage: String, toastMessage: String)

    /// 장수 소진. 서버 연동 전까지 쓰는 기본 사유.
    public static let noCardsLeft = Self.unavailable(
        viewportMessage: "앗.. 장수를 다 사용했어요!",
        toastMessage: "앗! 장수가 없어서 촬영할 수 없어요."
    )

    var viewportMessage: String? {
        guard case let .unavailable(viewportMessage, _) = self else { return nil }
        return viewportMessage
    }

    var toastMessage: String? {
        guard case let .unavailable(_, toastMessage) = self else { return nil }
        return toastMessage
    }
}
