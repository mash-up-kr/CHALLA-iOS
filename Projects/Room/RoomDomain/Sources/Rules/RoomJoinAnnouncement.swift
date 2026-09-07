import Foundation

/// 방 참여 안내 문구 규칙 — "{닉네임}이/가 {방 이름}에 참여했어요."
///
/// 방 이름은 여기서 자르지 않는다. 남는 폭이 닉네임 길이·기기 폭에 따라 달라져서, 뷰가 말줄임한다.
public enum RoomJoinAnnouncement {

    /// 닉네임이 이 글자 수를 넘으면 잘라 말줄임한다.
    public static let nicknameLimit = 8

    public static func nickname(_ nickname: String) -> String {
        guard nickname.count > nicknameLimit else { return nickname }
        return String(nickname.prefix(nicknameLimit)) + "…"
    }

    /// 주격 조사. 앞 글자에 받침이 있으면 "이", 없으면 "가".
    ///
    /// 말줄임된 닉네임은 말줄임표를 건너뛰고 그 앞 글자로 판단한다 — 읽히는 대로 고르기 위해서다.
    public static func subjectParticle(after text: String) -> String {
        guard let last = text.last(where: { $0 != "…" }) else { return "가" }
        return hasFinalConsonant(last) ? "이" : "가"
    }

    /// 완성형 한글은 코드값으로 받침을 판단하고, 숫자는 읽는 소리를 기준으로 한다.
    /// 그 밖의 문자(영문 등)는 받침 없음으로 본다.
    static func hasFinalConsonant(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }

        if (0xAC00 ... 0xD7A3).contains(scalar.value) {
            return (scalar.value - 0xAC00) % 28 != 0
        }
        // 영(0)·일(1)·삼(3)·육(6)·칠(7)·팔(8)에 받침이 있다.
        if let digit = character.wholeNumberValue, (0 ... 9).contains(digit) {
            return [0, 1, 3, 6, 7, 8].contains(digit)
        }
        return false
    }
}
