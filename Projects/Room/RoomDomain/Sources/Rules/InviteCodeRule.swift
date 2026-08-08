import Foundation

/// 초대 코드 규칙. 지금은 빈 값만 거른다 — 자릿수·문자셋은 형식 미확정.
public enum InviteCodeRule {

    /// 앞뒤 공백을 뗀 값. 대소문자는 바꾸지 않는다.
    public static func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 공백만 친 코드를 거른다.
    public static func isSubmittable(_ raw: String) -> Bool {
        !trimmed(raw).isEmpty
    }
}
