import Foundation

/// 초대 코드가 지켜야 할 조건. 입력값을 서버로 보낼 형태로 다듬고, 제출 가능 여부를 판단한다.
///
/// 길이를 자르는 `RoomNameRule`과 반대로 입력을 관대하게 받아준다 — 복사해 붙여넣으면
/// 앞뒤 공백이 딸려오는데 그대로 보내면 없는 코드가 된다.
/// 형식(자릿수·문자셋)이 정해지면 여기에 검사를 추가한다.
public enum InviteCodeRule {

    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 정규화한 뒤 판단해야 공백만 입력한 값이 걸러진다.
    public static func isSubmittable(_ raw: String) -> Bool {
        !normalize(raw).isEmpty
    }
}
