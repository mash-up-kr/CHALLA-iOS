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
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port, !port.isEmpty {
            components.port = Int(port)
        }
        guard let url = components.url else {
            fatalError("API_SCHEME/API_HOST/API_PORT로 baseURL을 구성할 수 없습니다. 앱 타깃이 makeAppProject(usesAPIEnvironment: true)를 쓰는지 확인하세요.")
        }
        return url
    }

    private static func infoPlistValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
