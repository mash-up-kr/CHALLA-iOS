import Foundation

/// 프로필 사진을 어떻게 할 것인지.
///
/// `Data?` 하나로는 표현할 수 없어서 도입했다 — nil이 "안 건드렸다"인지 "지웠다"인지 구분되지 않는다.
/// 서버는 `PUT`으로 전체를 덮어쓰고 `profileImageUrl`을 nil이어도 키째 받으므로,
/// 편집에서 사진을 안 건드렸을 때 nil을 보내면 기존 사진이 지워진다.
public enum ProfileImageChange: Sendable, Equatable {

    /// 사진을 건드리지 않았다 — 서버에 있던 URL을 그대로 되돌려 보낸다.
    /// 최초 설정에서는 아직 URL이 없으므로 nil이 온다.
    case unchanged(URL?)

    /// 새로 고른 사진. 업로드한 뒤 그 URL로 저장한다.
    case replaced(Data)

    /// 사진을 지웠다.
    case removed
}

/// 프로필 생성/수정 요청 입력. 필드를 늘려도 호출부 시그니처가 안 바뀌도록 struct로 감쌌다.
public struct ProfileDraft: Sendable, Equatable {

    /// 이미 normalized 된 값.
    public let nickname: String

    public let image: ProfileImageChange

    public init(nickname: String, image: ProfileImageChange = .unchanged(nil)) {
        self.nickname = nickname
        self.image = image
    }
}

// TODO(API 배포 후): 업로드 계약이 정해지면 contentType/fileName을 추가한다.
