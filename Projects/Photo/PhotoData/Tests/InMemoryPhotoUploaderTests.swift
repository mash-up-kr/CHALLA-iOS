import Foundation
import PhotoData
import PhotoDomain
import Testing

@Suite("InMemoryPhotoUploader")
struct InMemoryPhotoUploaderTests {

    @Test("업로드할 때마다 그 방의 남은 장수가 1씩 줄어든다")
    func decrementsRemainedCount() async throws {
        let uploader = InMemoryPhotoUploader(remainedPhotoCounts: [1: 2])

        #expect(try await uploader.upload(jpegData: Data(), roomID: 1, filterName: "Warm") == 1)
        #expect(try await uploader.upload(jpegData: Data(), roomID: 1, filterName: "Warm") == 0)
    }

    @Test("장수가 소진된 방에 올리면 photoExhausted를 던진다")
    func throwsWhenExhausted() async {
        let uploader = InMemoryPhotoUploader(remainedPhotoCounts: [1: 0])

        await #expect(throws: PhotoError.photoExhausted) {
            _ = try await uploader.upload(jpegData: Data(), roomID: 1, filterName: "Warm")
        }
    }

    @Test("지정한 실패는 차감 없이 그대로 던진다")
    func throwsConfiguredFailure() async {
        let uploader = InMemoryPhotoUploader(remainedPhotoCounts: [1: 5], failure: .network)

        await #expect(throws: PhotoError.network) {
            _ = try await uploader.upload(jpegData: Data(), roomID: 1, filterName: "Warm")
        }
    }
}
