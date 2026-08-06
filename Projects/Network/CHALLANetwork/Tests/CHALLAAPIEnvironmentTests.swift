@testable import CHALLANetwork
import Foundation
import Testing

@Suite("CHALLAAPIEnvironment")
struct CHALLAAPIEnvironmentTests {

    @Test("scheme·host·port를 조합해 baseURL을 만든다")
    func basicComposition() {
        let url = CHALLAAPIEnvironment.makeBaseURL(scheme: "http", host: "example.com", port: "8080")
        #expect(url.absoluteString == "http://example.com:8080")
    }

    @Test("port가 빈 문자열이면 기본 포트를 쓴다 (포트 생략)")
    func emptyPortOmitsPort() {
        let url = CHALLAAPIEnvironment.makeBaseURL(scheme: "https", host: "api.challa.app", port: "")
        #expect(url.absoluteString == "https://api.challa.app")
    }

    @Test("port가 nil이면 포트를 생략한다")
    func nilPortOmitsPort() {
        let url = CHALLAAPIEnvironment.makeBaseURL(scheme: "https", host: "api.challa.app", port: nil)
        #expect(url.absoluteString == "https://api.challa.app")
    }

    @Test("port가 숫자가 아니면 무시하고 포트 없이 조립한다")
    func nonNumericPortIsIgnored() {
        let url = CHALLAAPIEnvironment.makeBaseURL(scheme: "https", host: "api.challa.app", port: "not-a-number")
        #expect(url.absoluteString == "https://api.challa.app")
    }

    @Test("RFC 3986 형식을 만족하는 scheme만 통과시킨다")
    func schemeValidation() {
        #expect(CHALLAAPIEnvironment.isValidScheme("http"))
        #expect(CHALLAAPIEnvironment.isValidScheme("https"))
        #expect(CHALLAAPIEnvironment.isValidScheme("challa-app.v2+x"))

        #expect(!CHALLAAPIEnvironment.isValidScheme(""))
        #expect(!CHALLAAPIEnvironment.isValidScheme("1http")) // 숫자로 시작
        #expect(!CHALLAAPIEnvironment.isValidScheme("http://")) // 구분자 포함
        #expect(!CHALLAAPIEnvironment.isValidScheme("ht tp")) // 공백 포함
    }
}
