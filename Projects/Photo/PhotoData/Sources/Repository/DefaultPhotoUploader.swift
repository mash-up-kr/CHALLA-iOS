import CHALLAImageKit
import CHALLANetwork
import Foundation
import PhotoDomain

/// `PhotoUploader`의 실서버 구현 — 3단계 절차를 한 호출로 감춘다:
/// 서명 URL 발급(`POST /uploads`) → 스토리지 직접 PUT → 완료 통보(`POST /photos`).
/// 촬영본이 서버 상한(5MB)을 넘으면 발급 전에 상한 이하로 압축한다.
/// `DefaultProfileImageUploader`와 같은 구조이며, 용도(purpose)와 완료 API만 다르다.
public struct DefaultPhotoUploader: PhotoUploader {

    private let client: any HTTPClient
    private let compressor = ImageCompressor()

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func upload(jpegData: Data, roomID: Int64, filterName: String) async throws -> Int {
        do {
            // 서명 URL이 5분 만료라 시간이 걸릴 수 있는 압축을 발급보다 먼저 끝낸다.
            let uploadData = try compressor.compress(data: jpegData, maxBytes: Const.maxUploadBytes)

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
                .request(UploadEndpoint.put(url: uploadURL, data: uploadData, contentType: Const.contentType))
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
        /// 서버 업로드 상한. 넘는 촬영본은 필터가 구워진 픽셀 그대로 이 크기 이하로 압축해 올린다.
        static let maxUploadBytes = 5 * 1024 * 1024
    }
}
