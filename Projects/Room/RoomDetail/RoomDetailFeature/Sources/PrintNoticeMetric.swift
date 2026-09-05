import CoreGraphics

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
    static let filmTopPadding: CGFloat = 32
    /// 필름이 보이기 시작하는 자리 = 출구 아랫변(테두리 포함).
    static let filmWindowTopPadding: CGFloat = bezelTopPadding + bezelHeight + bezelBorderWidth
    /// 슬롯부터 출구 아랫변까지 — 출구에 가려 그리지 않는 길이.
    static let filmHiddenByBezel: CGFloat = filmWindowTopPadding - filmTopPadding

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
    /// 그중 실제로 보이는 길이 — 출구에 가려지는 만큼을 뺀 값.
    static let restReveal: CGFloat = initialReveal - filmHiddenByBezel
    /// 당길 곳을 알릴 때 필름이 조금 더 나왔다 들어가는 거리 (시안 없음 — 눈으로 잡은 값).
    static let hintDistance: CGFloat = 12
    /// 툴팁과 필름 끝 사이 — 시안 툴팁 top 374 − 필름 bottom 358.
    static let tooltipSpacing: CGFloat = 16
}
