import Dependencies
import DependenciesMacros
import UIKit

/// 클립보드 쓰기 의존성. `UIPasteboard.general` 싱글턴을 리듀서가 직접 만지지 않기 위해 감쌌다
/// (tca-feature 규칙: 싱글턴·전역 인스턴스 직접 접근 금지 — TestStore에서 교체 가능해야 한다).
@DependencyClient
struct CopyToPasteboard: Sendable {
    var run: @Sendable (_ text: String) async -> Void
}

extension CopyToPasteboard: DependencyKey {

    /// UseCase들과 달리 liveValue를 바로 채운다 — Data 접근이 없어(OS 호출 한 줄)
    /// 합성 루트에서 조립할 것이 없다. 앱·데모 어디서든 자동으로 이 구현이 잡힌다.
    static let liveValue = CopyToPasteboard { text in
        await MainActor.run { UIPasteboard.general.string = text }
    }

    /// 미구현 — 테스트가 갈아끼우지 않은 채 호출되면 테스트 실패로 보고된다.
    /// (liveValue만 두면 테스트 문맥에서 .testValue 접근 자체가 실패로 보고된다.)
    static let testValue = CopyToPasteboard()
}

extension DependencyValues {
    var copyToPasteboard: CopyToPasteboard {
        get { self[CopyToPasteboard.self] }
        set { self[CopyToPasteboard.self] = newValue }
    }
}
