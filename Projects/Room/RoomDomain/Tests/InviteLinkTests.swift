@testable import RoomDomain
import Foundation
import Testing

/// 초대 링크 규칙 — 만들기(보낼 때)와 파싱(받을 때)이 같은 모양을 쓰는지,
/// 우리 링크가 아닌 URL을 거르는지 검증한다.
@Suite("InviteLink")
struct InviteLinkTests {

    @Test("코드로 만든 링크는 도메인/invite/코드 모양이다")
    func buildsExpectedShape() {
        #expect(InviteLink.url(code: "1928121")?.absoluteString
            == "https://challa.stellaris.co.kr/invite/1928121")
    }

    @Test("만든 링크를 파싱하면 같은 코드가 나온다")
    func roundTrips() {
        let url = InviteLink.url(code: "1928121")
        #expect(url.flatMap(InviteLink.code(from:)) == "1928121")
    }

    @Test("공백만 친 코드로는 링크를 만들지 않는다")
    func rejectsBlankCode() {
        #expect(InviteLink.url(code: "   ") == nil)
    }

    @Test("우리 링크가 아니면 코드를 꺼내지 않는다", arguments: [
        "https://example.com/invite/1928121", // 다른 도메인
        "http://challa.stellaris.co.kr/invite/1928121", // https 아님
        "https://challa.stellaris.co.kr/join/1928121", // 다른 경로
        "https://challa.stellaris.co.kr/invite", // 코드 없음
        "https://challa.stellaris.co.kr/invite/19/28" // 경로가 더 깊음
    ])
    func rejectsForeignURL(raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(InviteLink.code(from: url) == nil)
    }

    @Test("주소를 대문자로 적어도(HTTPS://CHALLA.…) 초대 코드를 꺼낸다")
    func toleratesUppercase() throws {
        let url = try #require(URL(string: "HTTPS://CHALLA.stellaris.co.kr/invite/1928121"))
        #expect(InviteLink.code(from: url) == "1928121")
    }

    @Test("링크 뒤에 ?utm_source= 같은 쿼리가 붙어도 초대 코드를 꺼낸다")
    func toleratesQueryParameters() throws {
        // 카톡 같은 공유 플랫폼이 링크를 유통하며 추적용 쿼리를 임의로 붙일 수 있다 — 그 경우에 대비한다.
        let url = try #require(URL(string: "https://challa.stellaris.co.kr/invite/1928121?utm_source=kakao"))
        #expect(InviteLink.code(from: url) == "1928121")
    }

    @Test("끝 슬래시는 무시하고 코드를 꺼낸다")
    func toleratesTrailingSlash() throws {
        let url = try #require(URL(string: "https://challa.stellaris.co.kr/invite/1928121/"))
        #expect(InviteLink.code(from: url) == "1928121")
    }
}
