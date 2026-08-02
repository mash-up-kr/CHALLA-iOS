import Foundation

/// 초대 코드가 지켜야 할 조건. 입력값을 서버로 보낼 형태로 다듬고, 제출 가능 여부를 판단한다.
///
/// 길이를 잘라 제약을 강제하는 `RoomNameRule`과 방향이 반대다 — 이쪽은 입력을 관대하게
/// 받아준다. 카카오톡 등에서 복사해 붙여넣으면 앞뒤 공백이 딸려오는데, 그대로 서버에
/// 보내면 없는 코드가 되기 때문이다.
///
/// 형식(자릿수·문자셋)이 정해지면 여기에 검사를 추가한다. 그전까지 틀린 코드는
/// 서버가 `RoomError.roomNotFound`로 알려준다.
public enum InviteCodeRule {

    /// 앞뒤 공백·개행을 제거한다.
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "입장" 버튼 활성 조건. 정규화한 뒤 판단해야 공백만 입력한 값이 걸러진다.
    public static func isSubmittable(_ raw: String) -> Bool {
        !normalize(raw).isEmpty
    }
}
