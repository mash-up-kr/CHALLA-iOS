@testable import SettingDomain
import Testing

struct NotificationSettingTests {

    @Test("기본값은 꺼짐 — 시안의 기본 상태가 OFF다")
    func defaultIsOff() {
        #expect(NotificationSetting.default.isServiceEnabled == false)
    }

    @Test("서비스 알림 값이 그대로 보존된다")
    func preservesValue() {
        #expect(NotificationSetting(isServiceEnabled: true).isServiceEnabled == true)
        #expect(NotificationSetting(isServiceEnabled: false).isServiceEnabled == false)
    }
}
