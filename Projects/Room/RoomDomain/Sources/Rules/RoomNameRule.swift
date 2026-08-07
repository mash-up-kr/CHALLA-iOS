import Foundation

/// 방 이름이 지켜야 할 조건. 입력 즉시 길이를 자르고, 제출 가능 여부를 판단한다.
///
/// `Room`이 아니라 `String`을 받는다 — 방을 만들기 전 입력창에서 검사해야 하는데
/// 그 시점에는 `Room`이 없다. UseCase 안이 아닌 별도 규칙인 이유도 같다:
/// 버튼 활성 판단은 타이핑마다 동기로 일어나는데 UseCase는 `async`라 그 자리에 못 쓴다.
public enum RoomNameRule {

    /// 공백 포함 최대 길이 (시안 명세).
    public static let maxLength = 20

    /// 입력 즉시 길이를 자른다. Character 단위라 한글·조합 이모지도 한 글자로 센다.
    public static func sanitize(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// 서버로 보낼 형태로 앞뒤 공백을 뗀다. 타이핑 중에는 쓰지 않는다 —
    /// 단어 사이 공백을 칠 때마다 지워지면 입력이 막힌다.
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "만들기" 버튼 활성 조건. 정규화한 뒤 판단해야 공백만 입력한 값이 걸러진다.
    public static func isSubmittable(_ raw: String) -> Bool {
        !normalize(raw).isEmpty
    }
}
