import Foundation

/// 구독 스트림에 흐르는 이벤트.
public enum STOMPEvent: Sendable, Equatable {

    /// 서버가 보낸 메시지 본문. 해석은 Data 레이어가 한다.
    case message(Data)

    /// 끊겼다 다시 붙어 구독이 재설정됐다.
    /// 끊겨 있던 동안의 메시지는 오지 않으므로, 받는 쪽이 REST로 그 구간을 메워야 한다.
    case resumed
}

/// STOMP 구독 창구. Data 레이어가 보는 유일한 접점이다.
///
/// 연결·재연결·토큰 갱신은 구현체 안에서 끝난다. 호출부는 "구독하면 이벤트가 흘러온다"만 알면 된다.
public protocol STOMPClienting: Sendable {

    /// destination을 구독한다. 서버의 RECEIPT를 받은 뒤(또는 짧은 타임아웃 뒤) 리턴하므로,
    /// 리턴 이후에 시작한 REST 조회는 구독 시작 시점과 겹쳐 이벤트를 놓치지 않는다.
    ///
    /// 반환된 스트림의 소비가 끝나면(Task 취소 포함) UNSUBSCRIBE까지 자동으로 나간다.
    func subscribe(to destination: String) async throws -> AsyncThrowingStream<STOMPEvent, any Error>

    /// 앱이 백그라운드로 갔다. 소켓을 정리하되 구독 기록은 남긴다.
    /// (OS가 소켓을 끊어도 `receive()`가 영영 돌아오지 않는 경우가 있어 앱이 직접 알려야 한다.)
    func applicationDidEnterBackground() async

    /// 앱이 포그라운드로 돌아왔다. 남아 있는 구독이 있으면 즉시 다시 연결한다.
    func applicationWillEnterForeground() async
}
