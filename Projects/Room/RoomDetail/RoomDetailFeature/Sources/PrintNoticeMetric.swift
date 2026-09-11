import CoreGraphics
import Foundation

/// 필름 사진을 미리 받아 두는 쪽(홈)이 참조하라고 밖으로 여는 값.
///
/// 로더의 캐시 키가 `URL + 픽셀 크기`라, 이 크기로 받아 두지 않으면 필름이 캐시를 못 쓰고 다시 받는다.
/// 미리 받은 것이 통째로 버려지므로 양쪽이 반드시 같은 값을 봐야 한다.
public enum PrintNoticeFilmMetric {

    /// 필름 한 칸의 사진 크기(pt). 정수로 올린 값이다 — `ImageLoadSize.quantized`와 같은 규칙.
    public static let photoPointSize = CGSize(
        width: PrintNoticeMetric.photoWidth.rounded(.up),
        height: PrintNoticeMetric.photoHeight.rounded(.up)
    )
}

/// 시안 좌표는 화면 맨 위 기준이라, 상단 바(114) 아래에 놓이는 이 화면에서는 그만큼 뺀 값을 쓴다.
enum PrintNoticeMetric {

    /// 출구 위 여백 — 시안 top 131 − 상단 바 높이 114.
    static let bezelTopPadding: CGFloat = 17
    /// 출구 크기 (시안 313×30).
    static let bezelWidth: CGFloat = 313
    static let bezelHeight: CGFloat = 30
    /// 출구 테두리 (시안 4, 바깥쪽).
    static let bezelBorderWidth: CGFloat = 4
    /// 출구 그림자 (시안 y 18 · blur 111 · 검정 22%). SwiftUI 반경은 blur의 절반을 쓴다.
    static let bezelShadowOpacity: CGFloat = 0.22
    static let bezelShadowRadius: CGFloat = 55
    static let bezelShadowOffsetY: CGFloat = 18
    /// 출구 안쪽 슬롯 (시안 265×6).
    static let slotWidth: CGFloat = 265
    static let slotHeight: CGFloat = 6

    /// 필름이 나오는 자리 — 시안 필름 top 146 − 상단 바 높이 114 (슬롯의 세로 중앙).
    /// 필름은 출구 아랫변이 아니라 이 슬롯에서 나온다. 슬롯 아래 출구 테두리는 필름이 덮는다.
    static let filmTopPadding: CGFloat = 32

    /// 필름 폭 (시안 224.207 = 천공 18 + 사진 188.207 + 천공 18).
    static let filmWidth: CGFloat = 224
    static let perforationWidth: CGFloat = 18
    static let photoWidth: CGFloat = filmWidth - perforationWidth * 2

    /// 천공 구멍 (시안 6×8, 세로 간격 24 = 구멍 8 + 사이 16, 첫 구멍 top 12).
    static let holeWidth: CGFloat = 6
    static let holeHeight: CGFloat = 8
    static let holeSpacing: CGFloat = 16
    static let holePitch: CGFloat = holeHeight + holeSpacing
    static let holeTopInset: CGFloat = 12
    static let holeOpacity: CGFloat = 0.4

    /// 필름 한 칸과 그 안의 사진 (시안 151.254, 사진은 위아래 5씩 들어간 188.207×141.254).
    static let frameHeight: CGFloat = 151.25
    static let photoVerticalInset: CGFloat = 5
    static let photoHeight: CGFloat = frameHeight - photoVerticalInset * 2
    /// 사진 테두리 (시안 0.39).
    static let photoBorderWidth: CGFloat = 0.39

    /// 진입 직후 슬롯 밖으로 나와 있는 필름 길이 (시안0의 필름 높이 212).
    static let initialReveal: CGFloat = 212
    /// 당길 곳을 알릴 때 필름이 조금 더 나왔다 들어가는 거리 (시안 없음 — 눈으로 잡은 값).
    static let hintDistance: CGFloat = 12
    /// 툴팁과 필름 끝 사이 — 시안 툴팁 top 374 − 필름 bottom 358.
    static let tooltipSpacing: CGFloat = 16

    /// 손을 뗀 뒤 필름이 내려가는 속도(pt/초)와 시간의 상·하한.
    /// 상한이 있어 긴 필름(48·72장)은 이 속도보다 빠르게 지나간다.
    static let runSpeed: CGFloat = 1700
    static let minRunDuration: TimeInterval = 0.6
    static let maxRunDuration: TimeInterval = 4.0

    /// 칸 수만으로 어림한, 필름이 다 지나가는 시간.
    ///
    /// 실제로는 화면 높이만큼 더 내려가므로 이 값보다 조금 더 걸린다 — 짧게 잡히는 쪽이라
    /// 당기기를 열지 판단할 때 쓰기 안전하다. 사진이 적은 방은 필름도 짧아 금방 지나가므로,
    /// 고정값을 쓰면 그런 방에서 너무 일찍 열린다.
    static func runDuration(frameCount: Int) -> TimeInterval {
        let distance = CGFloat(frameCount) * frameHeight
        return min(max(TimeInterval(distance / runSpeed), minRunDuration), maxRunDuration)
    }
}
