import Foundation

/// 로그아웃·회원 탈퇴.
///
/// 계정 자체는 Auth aggregate의 것이지만, 계정 관리 화면이 필요로 하는 모양만
/// 여기에 선언한다 (`SettingProfileProvider`와 같은 판단 — 그쪽 주석 참고).
///
/// **구현체는 `SettingData`에 두지 않는다.** 로그아웃의 정본은 `AuthDomain.LogoutUseCase`이고
/// (서버 로그아웃 + 토큰 삭제까지 한다), 실행 앱의 `CompositionRoot`가 그것을 감싼 어댑터를 주입한다.
/// 탈퇴는 아직 어디에도 없어 `AuthDomain`에 추가해야 한다.
///
/// 구현체는 실패를 `SettingError`로 정규화해 던져야 한다.
public protocol AccountRepository: Sendable {

    /// 저장된 세션을 지운다. 성공하면 App이 로그인 화면으로 되돌린다.
    func signOut() async throws

    /// 계정을 삭제한다. 성공하면 되돌릴 수 없다.
    func deleteAccount() async throws
}
