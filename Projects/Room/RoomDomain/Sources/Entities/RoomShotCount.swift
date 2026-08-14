/// 방을 만들 때 고르는 촬영 매수. 시안의 "얼마나 찍을까요? 24장 / 48장 / 72장"에 대응한다.
///
/// `Int`면 37 같은 값이 들어올 수 있어 enum으로 두고, 원시값을 `Int`로 잡아
/// 값과 화면 표기("24장")가 따로 놀지 않게 한다.
public enum RoomShotCount: Int, CaseIterable, Equatable, Sendable {
    case twentyFour = 24
    case fortyEight = 48
    case seventyTwo = 72

    public static let `default` = RoomShotCount.twentyFour
}
