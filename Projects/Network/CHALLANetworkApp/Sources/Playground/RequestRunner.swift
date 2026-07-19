import Foundation
import Observation
import CHALLANetwork

/// 버튼이 눌리면 `DefaultHTTPClient`로 요청을 보내고 결과를 화면용 상태로 보관한다.
/// CHALLANetwork를 조립·주입하는 지점(데모앱은 앱 조립 지점이므로 허용).
@MainActor
@Observable
final class RequestRunner {

    enum Outcome {
        case idle
        case loading
        case success(status: Int, body: String)
        case failure(String)
    }

    private(set) var outcome: Outcome = .idle

    private let client: HTTPClient

    /// - Parameter useAuth: 참이면 `AuthInterceptor`(데모 토큰)를 파이프라인에 추가한다.
    /// View.init(비격리)에서 생성하므로 nonisolated.
    nonisolated init(useAuth: Bool) {
        var interceptors: [any Interceptor] = [LoggingInterceptor(level: .verbose)]
        if useAuth {
            interceptors.insert(
                AuthInterceptor(tokenProvider: DemoTokenProvider(token: "demo-access-token")),
                at: 0
            )
        }
        self.client = DefaultHTTPClient(interceptors: interceptors)
    }

    func run(_ endpoint: SampleEndpoint) async {
        outcome = .loading
        do {
            // 원본 Response를 받아 상태 코드/본문을 그대로 보여준다.
            // (2xx만 통과시키려면 client.request(endpoint, as:)를 쓰면 된다.)
            let response = try await client.request(endpoint)
            let body = Self.prettyPrinted(response.data)
            if (200..<300).contains(response.statusCode) {
                outcome = .success(status: response.statusCode, body: body)
            } else {
                outcome = .failure("HTTP \(response.statusCode)\n\n\(body)")
            }
        } catch let error as NetworkError {
            outcome = .failure(error.localizedDescription)
        } catch {
            outcome = .failure(error.localizedDescription)
        }
    }

    /// 디코딩 경로 데모 — `request(_:as:)`로 2xx 필터 + `Decodable` 매핑까지 실제로 태운다.
    func runDecoded() async {
        outcome = .loading
        do {
            let posts = try await client.request(SampleEndpoint.posts, as: [SamplePostDTO].self)
            let firstTitle = posts.first?.title ?? "-"
            outcome = .success(
                status: 200,
                body: "디코딩 성공: [SamplePostDTO] \(posts.count)개\n첫 제목: \(firstTitle)"
            )
        } catch let error as NetworkError {
            outcome = .failure(error.localizedDescription)
        } catch {
            outcome = .failure(error.localizedDescription)
        }
    }

    /// 응답 본문을 보기 좋게 정렬한다.
    private static func prettyPrinted(_ data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let string = String(data: pretty, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        }
        return string
    }
}
