import Foundation

/// 방 이름이 지켜야 할 조건. 입력 즉시 길이를 자르고, 제출 가능 여부를 판단한다.
///
/// Domain이 소유하는 이유 — 20자 상한은 서버 저장 한계와 맞물린 약속이라 화면 사정이 아니다.
/// Feature에 두면 방 이름을 다루는 화면이 늘 때마다(예: 이름 수정) 규칙이 복사되고,
/// 그중 하나만 안 고치면 화면마다 다르게 동작한다.
///
/// `Room` 인스턴스가 아니라 `String`을 받는 이유 — 방을 만들기 **전에** 입력창에서 검사해야
/// 하는데, 그 시점에는 `Room`이 아직 없다. 그래서 엔티티의 메서드가 아닌 독립 규칙으로 둔다.
///
/// 상태가 없어 인스턴스를 만들 일이 없으므로 케이스 없는 `enum`으로 선언한다.
public enum RoomNameRule {

    /// 공백 포함 최대 길이 (시안 명세).
    public static let maxLength = 20

    /// 입력 즉시 길이를 자른다. Character 단위라 한글·이모지 한 글자 = 1.
    public static func sanitize(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// "만들기" 버튼 활성 조건. 공백만 입력한 이름은 만들 수 없다.
    public static func isSubmittable(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
