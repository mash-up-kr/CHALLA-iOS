import SwiftUI

/// 탭 가능한 리스트 행의 우측(Trailing) 요소.
///
/// Zeplin `List` 섹션에 등록된 두 컴포넌트(`List / Arrow` · `List / Check`)와,
/// 설정 화면에서만 쓰이는 값 표시 변형을 담는다.
///
/// 토글 행은 여기 없다 — 행 전체가 스위치가 되어 `action`이 의미를 잃고 접근성 의미도
/// 달라지므로, `CHALLAListRow`의 별도 이니셜라이저(`init(_:description:icon:iconColor:isOn:)`)로 분리했다.
public enum CHALLAListRowAccessory: Sendable {

    /// 화면 이동을 뜻하는 화살표(CaretRight).
    /// `value`를 주면 화살표 왼쪽에 현재 값을 강조색으로 함께 보여준다 (예: `테마 → 레몬에이드 ›`).
    case arrow(value: String?)

    /// 선택 목록의 체크 표시. 미선택일 때도 자리를 차지하고 색만 흐려진다
    /// (시안이 체크를 숨기지 않고 `Label.disabled`로 남겨둔다).
    case check(isSelected: Bool)

    /// 우측 요소 없음.
    case empty

    /// 값 없이 화살표만.
    /// (enum 케이스에는 기본값을 줄 수 없어서 정적 프로퍼티로 연다 — 케이스와 이름이 겹쳐도 된다.)
    public static var arrow: Self {
        .arrow(value: nil)
    }
}
