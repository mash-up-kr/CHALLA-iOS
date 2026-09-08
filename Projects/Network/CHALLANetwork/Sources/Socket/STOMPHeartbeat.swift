import Foundation

/// 클라이언트가 보낼 하트비트 간격을 STOMP 1.2 규칙으로 정한다.
///
/// CONNECT가 `<cx>,<cy>`, CONNECTED가 `<sx>,<sy>`일 때 보낼 간격은
/// `cx`(내가 보낼 수 있는 최소 간격)와 `sy`(서버가 받고 싶은 간격) 중 **큰 값**이고,
/// 둘 중 하나라도 0이면 보내지 않는다.
///
/// 이 협상을 무시하면 서버가 "안 받겠다"고 한 하트비트를 계속 보내게 된다
/// (실제 서버는 `0,0`으로 답한다).
func stompOutgoingHeartbeat(clientCanSend: Int, connectedHeader: String?) -> Int {
    guard clientCanSend > 0 else { return 0 }
    // 헤더가 없으면 서버가 하트비트를 지원하지 않는 것으로 본다 (명세 기본값 0,0).
    guard let connectedHeader else { return 0 }

    let parts = connectedHeader.split(separator: ",", maxSplits: 1)
    guard
        parts.count == 2,
        let serverWants = Int(parts[1].trimmingCharacters(in: .whitespaces)),
        serverWants > 0
    else { return 0 }

    return max(clientCanSend, serverWants)
}
