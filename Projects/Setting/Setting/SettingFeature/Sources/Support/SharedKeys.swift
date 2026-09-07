import ComposableArchitecture
import SettingDomain

public extension SharedKey where Self == AppStorageKey<AppTheme>.Default {

    /// 사용자가 고른 테마. 고른 적이 없으면 `AppTheme.default`.
    ///
    /// 설정 화면과 앱 루트가 이 값 하나를 함께 읽는다. 값을 넘겨주는 코드가 없어서
    /// 화면 구조가 바뀌어도 전달 경로가 끊기지 않는다.
    ///
    /// 키에 마침표를 쓰지 않는다 — KVO가 마침표를 키패스 구분자로 읽어 값 변경 관찰이 깨진다.
    static var appTheme: Self {
        Self[.appStorage("challaSettingTheme"), default: .default]
    }
}
