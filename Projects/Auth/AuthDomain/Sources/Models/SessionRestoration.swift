import Foundation

/// 앱 시작 시 저장된 세션을 되살릴 수 있는지에 대한 판정 결과.
public enum SessionRestoration: Sendable, Equatable {

    /// 저장된 세션이 있다 — 자동 로그인을 이어서 진행한다.
    case restored

    /// 저장된 세션이 없다(또는 재설치 직후 초기화됐다) — 로그인 화면으로 보낸다.
    case signedOut
}
