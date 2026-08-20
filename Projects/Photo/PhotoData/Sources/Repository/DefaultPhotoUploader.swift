import CHALLANetwork
import Foundation
import PhotoDomain

/// `PhotoUploader`의 실서버 구현 — 3단계 절차를 한 호출로 감춘다:
/// 서명 URL 발급(`POST /uploads`) → 스토리지 직접 PUT → 완료 통보(`POST /photos`).
/// `DefaultProfileImageUploader`와 같은 구조이며, 용도(purpose)와 완료 API만 다르다.
public struct DefaultPhotoUploader: PhotoUploader {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func upload(jpegData: Data, roomID: Int64, filterName: String) async throws -> Int {
        do {
            let issued = try await client.request(
                UploadEndpoint.issue(
                    IssueUploadURLRequestDTO(purpose: Const.photoPurpose, contentType: Const.contentType)
                ),
                as: BaseResponseDTO<UploadURLResponseDTO>.self
            ).unwrap().upload

            guard let uploadURL = URL(string: issued.uploadUrl) else {
                throw PhotoError.unknown
            }

            // 서명 URL은 5분 만료·1회용 — 발급 직후 바로 올린다. 이 단계 실패는 서버가 모르므로
            // 완료 통보 없이 그대로 던지고, 재시도는 발급부터 다시 한다.
            _ = try await client
                .request(UploadEndpoint.put(url: uploadURL, data: jpegData, contentType: Const.contentType))
                .filterSuccessfulStatusCodes()

            let completed = try await client.request(
                PhotoEndpoint.complete(
                    CompletePhotoRequestDTO(roomID: roomID, cameraFilterName: filterName, imageURL: issued.imageUrl)
                ),
                as: BaseResponseDTO<CompletePhotoResponseDTO>.self
            )
            return try completed.unwrap().photo.remainedPhotoCount
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    private enum Const {
        static let photoPurpose = "PHOTO"
        static let contentType = "image/jpeg"
    }
}
