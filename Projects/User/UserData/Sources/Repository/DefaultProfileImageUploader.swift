import CHALLANetwork
import Foundation
import UIKit
import UserDomain

public struct DefaultProfileImageUploader: ProfileImageUploader {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func upload(_ imageData: Data) async throws -> URL {
        do {
            // 서버는 jpeg·png·webp만 받는데 사진 앱은 HEIC를 주는 경우가 많다 — 한 종류로 맞춰 올린다.
            let jpeg = try Self.jpegData(from: imageData)

            let issued = try await client.request(
                UploadEndpoint.issue(
                    IssueUploadURLRequestDTO(purpose: Const.profilePurpose, contentType: Const.contentType)
                ),
                as: BaseResponseDTO<UploadURLResponseDTO>.self
            ).unwrap().upload

            guard let uploadURL = URL(string: issued.uploadUrl),
                  let imageURL = URL(string: issued.imageUrl)
            else {
                throw UserError.unknown
            }

            _ = try await client
                .request(UploadEndpoint.put(url: uploadURL, data: jpeg, contentType: Const.contentType))
                .filterSuccessfulStatusCodes()

            return imageURL
        } catch {
            throw UserError.normalized(error)
        }
    }

    private enum Const {
        static let profilePurpose = "PROFILE_IMAGE"
        static let contentType = "image/jpeg"
        static let compressionQuality: CGFloat = 0.9
    }

    private static func jpegData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: Const.compressionQuality)
        else {
            throw UserError.unknown
        }
        return jpeg
    }
}
