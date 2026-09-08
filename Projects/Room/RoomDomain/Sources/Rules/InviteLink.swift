import Foundation

/// 초대 링크 규칙 — 링크의 모양(`https://challa.stellaris.co.kr/invite/{코드}`)을 아는 유일한 곳.
///
/// - 보낼 때: `url(code:)`가 코드를 링크로 만든다 — 방 상세의 공유 시트가 카톡 등으로 보낸다.
/// - 받을 때: `code(from:)`가 링크에서 코드를 꺼낸다 — 링크로 찰나앱이 열렸을 때 쓴다.
///
/// `url(code:)`로 만든 링크를 `code(from:)`에 넣으면 원래 코드가 그대로 나온다.
public enum InviteLink {

    /// 앱 링크 도메인 (백엔드 확정 2026-09-01, Associated Domains와 같은 값).
    private static let host = "challa.stellaris.co.kr"
    private static let pathPrefix = "invite"
    private static let scheme = "challa"

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

    /// 받을 때 — 링크에서 초대 코드를 꺼낸다. 두 모양을 받는다.
    /// - 유니버설 링크 `https://challa.stellaris.co.kr/invite/{코드}` — 메모·문자에서 링크를 탭했을 때
    /// - 커스텀 스킴 `challa://invite/{코드}` — 서버 폴백 페이지의 "앱에서 보기" 버튼이 쏜다
    ///   (카톡 인앱 브라우저에서는 유니버설 링크가 앱을 못 열어, 이 버튼이 우회로다)
    public static func code(from url: URL) -> String? {
        guard let code = universalLinkCode(from: url) ?? customSchemeCode(from: url)
        else { return nil }

        // 서버가 만든 링크는 항상 통과한다. 코드 자리가 공백인 잘못 만든 링크는 여기서 nil이 되어
        // 앱이 아무 반응도 하지 않는다. 이 검사가 없으면 그 공백이 초대 코드로 서버 입장
        // 요청까지 나갔다가 거절당해, 링크를 눌렀을 뿐인 사용자가 실패 얼럿을 보게 된다.
        return InviteCodeRule.isSubmittable(code) ? code : nil
    }

    /// 우리 도메인의 `/invite/{코드}` 모양일 때만 돌려준다 — 같은 도메인에 다른 경로가
    /// 생겨도 그 URL의 조각을 초대 코드로 읽지 않는다.
    private static func universalLinkCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "https", // 스킴도 host처럼 대소문자 무관 (RFC)
              url.host()?.lowercased() == host,
              url.pathComponents.count == 3, // "/" · "invite" · 코드
              url.pathComponents[1] == pathPrefix
        else { return nil }
        return url.pathComponents[2]
    }

    /// URL 문법상 `//` 뒤 첫 조각이 host라서, 커스텀 스킴에서는 `invite`가 host 자리에
    /// 서고 코드만 경로에 온다 — 유니버설 링크와 guard 모양이 다른 이유다.
    private static func customSchemeCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme,
              url.host()?.lowercased() == pathPrefix,
              url.pathComponents.count == 2 // "/" · 코드
        else { return nil }
        return url.pathComponents[1]
    }
}
