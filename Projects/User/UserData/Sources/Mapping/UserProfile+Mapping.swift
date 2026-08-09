import Foundation
import UserDomain

extension UserProfileResponseDTO {

    func toDomain() -> UserProfile {
        UserProfile(
            id: user.id,
            nickname: user.nickname,
            imageURL: user.profileImageUrl.flatMap(URL.init(string:))
        )
    }
}
