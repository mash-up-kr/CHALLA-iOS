import CHALLAImageKit
import CHALLANetwork
import Foundation
import PhotoDomain

/// `PhotoUploader`의 실서버 구현 — 절차를 한 호출로 감춘다:
/// 서명 URL 발급(`POST /uploads`) → 스토리지 직접 PUT → 완료 통보(`POST /photos`).
/// 촬영본이 서버 상한(5MB)을 넘으면 발급 전에 상한 이하로 압축한다.
///
/// 원본과 함께 축소본도 올린다. 목록·필름은 작게 보이는 화면이라 원본(장당 4~4.5MB)을 받으면
/// 사진이 도착하기 전에 화면이 지나간다. 서버는 축소본을 만들지 않으므로 앱이 만들어 함께 올린다.
/// 축소본은 없어도 되는 것이라, 만들거나 올리는 데 실패해도 원본 업로드는 그대로 끝낸다.
///
/// `DefaultProfileImageUploader`와 같은 구조이며, 용도(purpose)와 완료 API만 다르다.
public struct DefaultPhotoUploader: PhotoUploader {

    private let client: any HTTPClient
    private let compressor = ImageCompressor()
    private let thumbnailMaker = ImageThumbnailMaker()

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func upload(jpegData: Data, roomID: Int64, filterName: String) async throws -> Int {
        do {
            // 서명 URL이 5분 만료라 시간이 걸릴 수 있는 이미지 처리를 발급보다 먼저 끝낸다.
            let uploadData = try compressor.compress(data: jpegData, maxBytes: Const.maxUploadBytes)
            // 축소본은 실패해도 업로드를 멈추지 않는다 — 없으면 목록이 원본으로 폴백한다.
            let thumbnailData = try? thumbnailMaker.thumbnailJPEG(
                from: uploadData,
                maxPixelSize: Const.thumbnailMaxPixelSize
            )

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

            // 원본이 올라간 뒤에 올린다 — 실패해도 사진은 이미 스토리지에 있다.
            let thumbnailImageURL = await putThumbnail(thumbnailData, issued: issued)

            let completed = try await client.request(
                PhotoEndpoint.complete(
                    CompletePhotoRequestDTO(
                        roomID: roomID,
                        cameraFilterName: filterName,
                        imageURL: issued.imageUrl,
                        thumbnailImageURL: thumbnailImageURL
                    )
                ),
                as: BaseResponseDTO<CompletePhotoResponseDTO>.self
            )
            return try completed.unwrap().photo.remainedPhotoCount
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 축소본을 올리고, 성공했을 때만 공개 주소를 돌려준다.
    ///
    /// 실패를 던지지 않는다 — 여기서 던지면 이미 올라간 원본이 방에 반영되지 않고 버려진다.
    /// 주소가 nil이면 서버가 그 사진의 축소본을 비워 두고, 목록은 원본으로 폴백한다.
    private func putThumbnail(_ data: Data?, issued: UploadURLResponseDTO.Payload) async -> String? {
        guard let data,
              let imageURL = issued.thumbnailImageUrl,
              let uploadURL = issued.thumbnailUploadUrl.flatMap(URL.init(string:))
        else {
            return nil
        }

        do {
            _ = try await client
                .request(UploadEndpoint.put(url: uploadURL, data: data, contentType: Const.contentType))
                .filterSuccessfulStatusCodes()
            return imageURL
        } catch {
            return nil
        }
    }

    private enum Const {
        static let photoPurpose = "PHOTO"
        static let contentType = "image/jpeg"
        /// 서버 업로드 상한. 넘는 촬영본은 필터가 구워진 픽셀 그대로 이 크기 이하로 압축해 올린다.
        static let maxUploadBytes = 5 * 1024 * 1024
        /// 축소본의 긴 변(픽셀). 방 상세 그리드가 큰 기기에서 378px까지 쓰므로 그보다 커야 하고,
        /// 키울수록 필름이 전부 도착하기까지 오래 걸린다. 장당 약 40KB.
        static let thumbnailMaxPixelSize: CGFloat = 400
    }
}
