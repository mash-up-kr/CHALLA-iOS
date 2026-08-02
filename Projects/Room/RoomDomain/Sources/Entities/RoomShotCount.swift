/// 방을 만들 때 고르는 촬영 매수. 시안의 "얼마나 찍을까요? 24장 / 48장 / 72장"에 대응한다.
///
/// `Int`가 아닌 enum인 이유 — 셋 중 하나만 가능해야 한다. `Int`면 37 같은 값이 들어올 수 있다.
/// 원시값을 `Int`로 둔 이유 — 값과 화면 표기("24장")가 따로 놀지 않게 한다.
/// `CaseIterable`인 이유 — 선택 버튼을 `allCases`로 그린다. 매수가 추가돼도 뷰는 그대로다.
public enum RoomShotCount: Int, CaseIterable, Equatable, Sendable {
    case twentyFour = 24
    case fortyEight = 48
    case seventyTwo = 72

    public static let `default` = RoomShotCount.twentyFour
}
