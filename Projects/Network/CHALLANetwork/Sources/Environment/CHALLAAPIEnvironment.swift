import Foundation

/// 이 앱이 호출하는 백엔드 서버의 기본 baseURL.
///
/// 도메인마다 서버가 갈리지 않는 한, 모든 Data 모듈(`AuthData`·`RoomData` 등)의 `Endpoint`가
/// 공유하는 단일 소스다. 값은 앱 타깃 Info.plist(`API_SCHEME`/`API_HOST`/`API_PORT`)에서 읽으며,
/// 이 값은 `Configs/Shared.xcconfig`(gitignore) → `makeAppProject(usesAPIEnvironment: true)`로 주입된다.
/// 서버 이전·HTTPS 전환 시 `Configs/Shared.xcconfig` 한 곳만 고치면 이 값과 ATS 예외가 함께 바뀐다.
public enum CHALLAAPIEnvironment {

    public static let baseURL: URL = makeBaseURL(
        scheme: infoPlistValue(for: "API_SCHEME"),
        host: infoPlistValue(for: "API_HOST"),
        port: infoPlistValue(for: "API_PORT")
    )

    /// `URLComponents` 조립 로직만 분리한 순수 함수 — `Bundle.main` 의존 없이 유닛테스트 가능.
    static func makeBaseURL(scheme: String?, host: String?, port: String?) -> URL {
        // 빈 scheme·host를 그대로 넘기면 조립이 "성공"해 ""·"https:" 같은 못 쓰는 URL이 나오고,
        // 형식이 어긋난 scheme은 세터가 Foundation 내부에서 트랩해 아래 guard까지 오지도 않는다.
        guard let scheme, !scheme.isEmpty else {
            fatalError(misconfiguration(key: "API_SCHEME", detail: "값이 비어 있습니다."))
        }
        guard isValidScheme(scheme) else {
            fatalError(misconfiguration(key: "API_SCHEME", detail: "\"\(scheme)\"는 URL scheme 형식이 아닙니다 (예: http, https)."))
        }
        guard let host, !host.isEmpty else {
            fatalError(misconfiguration(key: "API_HOST", detail: "값이 비어 있습니다."))
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port, !port.isEmpty {
            components.port = Int(port)
        }
        guard let url = components.url else {
            fatalError(misconfiguration(key: "API_HOST", detail: "\"\(host)\"로 URL을 조립할 수 없습니다."))
        }
        return url
    }

    /// RFC 3986: `scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`
    static func isValidScheme(_ scheme: String) -> Bool {
        guard let first = scheme.first, first.isASCII, first.isLetter else { return false }
        return scheme.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }
    }

    private static func misconfiguration(key: String, detail: String) -> String {
        """
        \(key) 설정이 잘못됐습니다 — \(detail)
        Configs/Shared.xcconfig에 값이 있는지, 앱 타깃이 makeAppProject(usesAPIEnvironment: true)를 쓰는지 확인하세요.
        """
    }

    private static func infoPlistValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
