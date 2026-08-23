import Foundation
import RoomDomain
import Testing

@Suite("PrintCountdown")
struct PrintCountdownTests {

    @Test("남은 시간을 시:분:초로 표기한다", arguments: zip(
        [10798.0, 59.0, 3600.0], //   2시간 59분 58초 · 59초 · 정각 1시간
        ["2:59:58", "0:00:59", "1:00:00"]
    ))
    func countdownFormats(seconds: Double, expected: String) {
        let now = Date(timeIntervalSince1970: 0)

        #expect(PrintCountdown.text(until: now.addingTimeInterval(seconds), now: now) == expected)
    }

    @Test("완료 시각이 지나면 0:00:00으로 고정된다")
    func countdownClampsAtZero() {
        let now = Date(timeIntervalSince1970: 1000)

        #expect(PrintCountdown.text(until: now.addingTimeInterval(-5), now: now) == "0:00:00")
    }
}
