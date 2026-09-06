import Foundation

/// 초대 링크 규칙 — 링크의 모양(`https://challa.stellaris.co.kr/invite/{코드}`)을 아는 유일한 곳.
///
/// - 보낼 때: `url(code:)`가 코드를 링크로 만든다 — 방 상세의 공유 시트가 카톡 등으로 보낸다.
/// - 받을 때: `code(from:)`가 링크에서 코드를 꺼낸다 — 유니버설 링크로 찰나앱이 열렸을 때 쓴다.
///
/// `url(code:)`로 만든 링크를 `code(from:)`에 넣으면 원래 코드가 그대로 나온다.
public enum InviteLink {

    /// 앱 링크 도메인 (백엔드 확정 2026-09-01, Associated Domains와 같은 값).
    public static let host = "challa.stellaris.co.kr"
    private static let pathPrefix = "invite"

    /// 보낼 때 — 초대 코드로 공유용 링크를 만든다. 공백만 친 코드면 nil.
    public static func url(code: String) -> URL? {
        let code = InviteCodeRule.trimmed(code)
        guard InviteCodeRule.isSubmittable(code) else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/\(pathPrefix)/\(code)"
        return components.url
    }

    /// 받을 때 — 유니버설 링크에서 초대 코드를 꺼낸다.
    /// 우리 도메인의 `/invite/{코드}` 모양일 때만 돌려준다 — 같은 도메인에 다른 경로가
    /// 생겨도 그 URL의 조각을 초대 코드로 읽지 않는다.
    public static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "https", // 스킴도 host처럼 대소문자 무관 (RFC)
              url.host()?.lowercased() == host,
              url.pathComponents.count == 3, // "/" · "invite" · 코드
              url.pathComponents[1] == pathPrefix
        else { return nil }

        let code = url.pathComponents[2]
        // 서버가 만든 링크는 항상 통과한다. 코드 자리가 공백인 잘못 만든 링크는 여기서 nil이 되어
        // 앱이 아무 반응도 하지 않는다. 이 검사가 없으면 그 공백이 초대 코드로 서버 입장
        // 요청까지 나갔다가 거절당해, 링크를 눌렀을 뿐인 사용자가 실패 얼럿을 보게 된다.
        return InviteCodeRule.isSubmittable(code) ? code : nil
    }
}
