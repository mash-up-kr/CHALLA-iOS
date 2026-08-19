import Foundation
import PhotoDomain

/// 데모·테스트용 가짜 업로더. 방별 남은 장수를 실서버처럼 차감해 돌려준다.
public actor InMemoryPhotoUploader: PhotoUploader {

    private var remainedByRoom: [Int64: Int]
    private let latency: Duration
    private let failure: PhotoError?

    public init(
        remainedPhotoCounts: [Int64: Int] = [:],
        latency: Duration = .zero,
        failure: PhotoError? = nil
    ) {
        remainedByRoom = remainedPhotoCounts
        self.latency = latency
        self.failure = failure
    }

    public func upload(jpegData _: Data, roomID: Int64, filterName _: String) async throws -> Int {
        if latency > .zero {
            try await Task.sleep(for: latency)
        }
        if let failure {
            throw failure
        }

        let remained = remainedByRoom[roomID] ?? 0
        guard remained > 0 else {
            throw PhotoError.photoExhausted // 실서버 기준과 같다 — 장수가 없는 방에는 올릴 수 없다
        }
        remainedByRoom[roomID] = remained - 1
        return remained - 1
    }
}
