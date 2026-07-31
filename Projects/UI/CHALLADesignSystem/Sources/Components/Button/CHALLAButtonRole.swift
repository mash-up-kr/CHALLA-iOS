import SwiftUI

/// 버튼의 의미(역할). variant가 생김새를 고른다면 role은 액션의 성격을 표시한다.
/// 서로 별개 축이라 어떤 variant와도 조합할 수 있다 — SwiftUI `Button(role:)`과 같은 개념.
/// 지정하지 않으면(nil) 평범한 버튼이고, 색은 variant의 기본 팔레트를 따른다.
///
/// enum인 이유: Status 팔레트에 positive·cautionary가 있어 역할이 늘어날 수 있고,
/// 역할은 동시에 하나만 가질 수 있어야 하며, 추가 시 색 매핑 switch가 컴파일 에러로 누락을 잡아준다.
/// Sendable: public 타입은 자동 부여가 없어 명시한다 — strict concurrency에서
/// Feature의 State 등 동시성 경계를 넘는 곳에 담아도 안전하다는 표시.
public enum CHALLAButtonRole: Sendable {
    /// 되돌릴 수 없는 액션(삭제·탈퇴 등).
    /// primary는 빨간 채움 + 밝은 글자, neutral·transparent는 빨간 글자가 된다.
    case destructive
}
