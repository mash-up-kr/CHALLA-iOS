import Foundation

/// 닉네임 입력 규칙 (서버·저장소와 무관한 순수 정책).
public enum NicknameRule {

    /// 서버는 1–20자를 허용하지만 시안 기준으로 더 좁게 잡는다 — 서버 값에 맞춰 넓히지 말 것.
    public static let maxLength = 10

    /// 규칙 위반 사유. `userMessage`는 토스트 문구 — 문구가 maxLength와 함께 움직여야 해서 Domain이 보유한다.
    public enum Violation: Error, Equatable, Sendable {
        case empty
        case tooLong(limit: Int)

        public var userMessage: String {
            switch self {
            case .empty:
                return "닉네임을 입력해 주세요."
            case let .tooLong(limit):
                return "공백 포함 \(limit)자까지 입력할 수 있어요"
            }
        }
    }

    /// 입력 즉시 적용하는 정리 규칙 — 한 줄 필드라 개행을 없앤다(붙여넣기 방어).
    ///
    /// 개행 외에는 입력을 그대로 보존한다. 값이 온전해야 `validate`가 "지금 이 값이 규칙을 어기는지"를
    /// 판정할 수 있고, 필드 테두리·제출 버튼이 타이머가 아니라 입력값을 따라 실시간으로 바뀐다.
    public static func sanitize(_ raw: String) -> String {
        String(raw.filter { !$0.isNewline && !isInvisible($0) })
    }

    /// 눈에 보이지 않는 문자 — zero-width space·joiner, 방향 제어 문자 등.
    ///
    /// 걸러내지 않으면 `U+200B`만 열 개 넣은 값이 `.empty`도 아니고 길이 10자로 통과해
    /// **빈 것처럼 보이는 닉네임**이 서버에 저장된다.
    /// `trimmingCharacters(in: .whitespacesAndNewlines)`는 이 문자들을 공백으로 보지 않는다.
    private static func isInvisible(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.properties.isDefaultIgnorableCodePoint || scalar.properties.generalCategory == .format
        }
    }

    /// 제출 가능 여부. nil이면 유효. 공백만 입력하면 `.empty`.
    ///
    /// 길이는 grapheme cluster 수로 세며 내부 공백도 1자다.
    /// **실제 전송되는 값(`normalized`) 기준으로 잰다** — 앞뒤 공백까지 세면
    /// "10자 + 뒤 공백"처럼 서버에 갈 때는 한도 안인 값이 거부된다.
    public static func validate(_ value: String) -> Violation? {
        let normalized = normalized(value)
        if normalized.isEmpty {
            return .empty
        }
        if normalized.count > maxLength {
            return .tooLong(limit: maxLength)
        }
        return nil
    }

    /// 서버 전송용 정규화 — 앞뒤 공백 제거(내부 공백은 보존).
    public static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
