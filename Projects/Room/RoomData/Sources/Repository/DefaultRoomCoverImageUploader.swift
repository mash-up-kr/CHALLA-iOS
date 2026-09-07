import CHALLANetwork
import Foundation
import RoomDomain

/// UserData의 DefaultProfileImageUploader와 같은 흐름 — 공통화는 #51 소관
public struct DefaultRoomCoverImageUploader: RoomCoverImageUploader {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    /// 입력은 Feature가 이미 JPEG로 줄여 놓은 바이트라 다시 인코딩하지 않는다
    public func upload(_ imageData: Data) async throws -> URL {
        do {
            let issued = try await client.request(
                UploadEndpoint.issue(
                    IssueUploadURLRequestDTO(purpose: Const.purpose, contentType: Const.contentType)
                ),
                as: BaseResponseDTO<UploadURLResponseDTO>.self
            ).unwrap().upload

            guard let uploadURL = URL(string: issued.uploadUrl),
                  let imageURL = URL(string: issued.imageUrl)
            else {
                throw RoomError.unknown
            }

            _ = try await client
                .request(UploadEndpoint.put(url: uploadURL, data: imageData, contentType: Const.contentType))
                .filterSuccessfulStatusCodes()

            return imageURL
        } catch {
            throw RoomError.normalized(error)
        }
    }

    private enum Const {
        static let purpose = "ROOM_COVER_IMAGE"
        static let contentType = "image/jpeg"
    }
}
