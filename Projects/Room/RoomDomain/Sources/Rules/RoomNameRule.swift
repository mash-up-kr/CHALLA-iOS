import Foundation

/// 방 이름 규칙. 타이핑마다 동기로 판단해야 해서 async인 UseCase 밖에 둔다.
public enum RoomNameRule {

    /// 공백 포함 최대 길이 (시안 명세).
    public static let maxLength = 20

    /// 20자로 자른 값. 타이핑할 때마다 쓴다. Character 단위라 한글·조합 이모지도 한 글자다.
    public static func truncated(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// 앞뒤 공백을 뗀 값. 제출할 때만 쓴다 — 타이핑 중에 쓰면 단어를 띄울 수 없다.
    public static func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 공백만 친 이름을 거른다.
    public static func isSubmittable(_ raw: String) -> Bool {
        !trimmed(raw).isEmpty
    }
}
