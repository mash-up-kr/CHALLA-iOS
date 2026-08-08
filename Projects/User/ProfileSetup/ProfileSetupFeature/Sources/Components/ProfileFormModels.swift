import Foundation

/// 헤드라인 문구. `highlighted`가 있으면 첫 줄을 lime 색으로 강조한다 (환영 화면의 닉네임).
struct ProfileFormHeadline: Equatable {
    var highlighted: String?
    /// 나머지 줄 (개행 포함 가능).
    var text: String
}

/// 아바타 이미지 소스. `remote`는 ProfileEdit(서버 이미지 URL) 대비.
enum ProfileAvatarSource: Equatable {
    case placeholder
    case local(Data)
    case remote(URL)
}

/// 닉네임 필드 표현 모드. 검증 판단은 리듀서가 하고, 뷰는 결과 모드만 받는다.
enum ProfileNicknameFieldMode: Equatable {
    case editable
    case invalid
    case readOnly
}

/// 하단 CTA 표현값. nil이면 버튼 미표시 (자리는 유지).
struct ProfileFormCTA {
    var title: String
    var isEnabled: Bool
    var isLoading: Bool
    var action: () -> Void
}
