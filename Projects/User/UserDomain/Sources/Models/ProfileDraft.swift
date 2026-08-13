import Foundation

/// 프로필 생성/수정 요청 입력. 필드를 늘려도 호출부 시그니처가 안 바뀌도록 struct로 감쌌다.
public struct ProfileDraft: Sendable, Equatable {
    /// 이미 normalized 된 값.
    public let nickname: String
    /// nil이면 기본 아바타 유지.
    public let imageData: Data?

    public init(nickname: String, imageData: Data? = nil) {
        self.nickname = nickname
        self.imageData = imageData
    }
}

// TODO(API 배포 후): 업로드 계약이 정해지면 contentType/fileName을 추가한다.
