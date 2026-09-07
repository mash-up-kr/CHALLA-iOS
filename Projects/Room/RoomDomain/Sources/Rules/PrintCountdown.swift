import Foundation

/// 인화 완료까지 남은 시간 표기 규칙. 홈 카드의 대기 뱃지와 방 상세 카운트다운 바가 함께 쓴다.
public enum PrintCountdown {

    /// "2:59:58" — 시는 자릿수 제한 없이, 분·초는 두 자리. 0 아래로 내려가지 않는다
    /// (완료 시각이 지나도 서버 상태가 갱신될 때까지 0:00:00으로 고정).
    public static func text(until end: Date, now: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        return "\(remaining / 3600):" + String(format: "%02d:%02d", remaining % 3600 / 60, remaining % 60)
    }
}
