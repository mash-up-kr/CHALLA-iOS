@testable import CHALLAImageKit
import Foundation

/// 테스트용 네트워크 페처. 반환값을 주입하고 호출 횟수를 센다.
///
/// 실제 `URLSession` 대신 이걸 `ImageLoader`에 주입하면 네트워크 없이(시뮬레이터에서) 검증할 수 있고,
/// `callCount`로 "캐시 히트 시 네트워크를 안 탔는가", "dedup으로 한 번만 탔는가"를 확인한다.
final class MockImageDataFetcher: ImageDataFetching, @unchecked Sendable {

    private let lock = NSLock()
    private var _callCount = 0

    /// `fetch(_:)`가 호출된 횟수(스레드 안전).
    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    private let delayNanoseconds: UInt64
    private let handler: @Sendable (URL) async throws -> (Data, URLResponse)

    /// - Parameters:
    ///   - delayNanoseconds: 응답 전 지연. dedup 테스트에서 요청들이 겹치도록 강제할 때 쓴다.
    ///   - handler: URL을 받아 (바이트, 응답)을 돌려주거나 던지는 클로저.
    init(
        delayNanoseconds: UInt64 = 0,
        handler: @escaping @Sendable (URL) async throws -> (Data, URLResponse)
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.handler = handler
    }

    func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        lock.lock()
        _callCount += 1
        lock.unlock()

        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return try await handler(url)
    }

    /// 지정 상태 코드의 HTTP 응답을 만든다. 생성 실패는 `badServerResponse`로 던진다.
    static func makeHTTPResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return response
    }

    /// 200 OK로 고정 바이트를 돌려주는 간편 생성기.
    static func ok(_ data: Data, delayNanoseconds: UInt64 = 0) -> MockImageDataFetcher {
        MockImageDataFetcher(delayNanoseconds: delayNanoseconds) { url in
            let response = try makeHTTPResponse(url: url, statusCode: 200)
            return (data, response)
        }
    }

    /// 처음 `times`번은 지정 코드로 실패하고, 그 뒤부터 200 OK로 `data`를 돌려주는 생성기.
    /// 재시도 로직(일시적 실패 후 복구)을 검증할 때 쓴다.
    static func failing(
        times: Int,
        thenReturn data: Data,
        errorCode: URLError.Code = .timedOut
    ) -> MockImageDataFetcher {
        let counter = CallCounter()
        return MockImageDataFetcher { url in
            if counter.next() <= times {
                throw URLError(errorCode)
            }
            let response = try makeHTTPResponse(url: url, statusCode: 200)
            return (data, response)
        }
    }
}

/// 클로저가 캡처해 호출 순번을 세는 스레드 안전 카운터.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
