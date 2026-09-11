import Foundation

/// 인화 완료 안내에서 당기기를 열어도 되는지 정하는 규칙.
///
/// 사진을 전부 받을 때까지 기다리지 않는다. 필름은 한 칸이 0.06초 만에 지나가는데,
/// 받는 속도가 그보다 빠르면 남은 장은 필름이 그 칸에 닿기 전에 도착한다.
///
/// 판단은 지금까지의 속도로 남은 장에 걸릴 시간을 어림해서 한다.
/// ``safetyWindow``에는 그 필름이 다 지나가는 데 걸리는 시간을 넣는다
/// (``PrintNoticeMetric/runDuration(frameCount:)``) — 사진이 적은 방은 필름도 짧아서
/// 고정값을 쓰면 너무 일찍 열린다.
///
/// 시간과 장수만 보는 순수 계산이라 뷰·스토어와 떼어 두고 따로 검증한다.
struct PrintNoticePullGate: Equatable {

    /// 열기 전에 반드시 채워 둘 칸 수. 멈춰 있는 동안 보이는 칸(1.3칸)에 여유를 더한 값이다 —
    /// 이 칸들은 사용자가 안내를 읽는 동안 계속 보이므로 비어 있으면 눈에 띈다.
    let minReadyFrames: Int

    /// 남은 장이 이 시간 안에 다 들어올 것으로 보이면 연다.
    let safetyWindow: TimeInterval

    /// - Parameters:
    ///   - total: 받기로 한 장수.
    ///   - leadingReady: 맨 앞에서부터 끊기지 않고 이어서 받은 장수.
    ///   - loaded: 지금까지 받은 장수. 실패한 장은 세지 않는다.
    ///   - elapsed: 받기 시작한 뒤 지난 시간.
    func isOpen(total: Int, leadingReady: Int, loaded: Int, elapsed: TimeInterval) -> Bool {
        // 앞 칸은 개수가 아니라 자리로 따진다. 뒤쪽이 먼저 도착해도 멈춰 있는 동안 보이는
        // 자리가 비어 있으면 검은 칸이 그대로 눈에 남는다.
        // 방이 앞 칸 수보다 작으면 전부 받아야 연다.
        guard total > 0, leadingReady >= min(total, minReadyFrames) else { return false }

        let remaining = total - loaded
        guard remaining > 0 else { return true }

        // 아직 시간이 흐르지 않았으면 속도를 알 수 없다 — 다음 장이 올 때 다시 본다.
        guard loaded > 0, elapsed > 0 else { return false }

        let secondsPerPhoto = elapsed / Double(loaded)
        return Double(remaining) * secondsPerPhoto <= safetyWindow
    }
}
