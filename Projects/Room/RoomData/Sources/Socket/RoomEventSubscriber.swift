import CHALLANetwork
import Foundation
import RoomDomain

/// `/topic/room/{roomId}/member-joined` 구독. 프레임 본문을 도메인 이벤트로 바꿔 흘린다.
public struct RoomEventSubscriber: RoomEventStreaming {

    private let client: any STOMPClienting
    private let decoder = JSONDecoder()

    public init(client: any STOMPClienting) {
        self.client = client
    }

    /// 사용자 단위 주소와 방 단위 주소를 **둘 다** 구독해 하나로 합친다.
    ///
    /// 서버가 사용자 단위 주소로 옮겨가는 중이라 어느 쪽으로 올지 시점을 앱이 알 수 없다.
    /// 둘 다 걸어 두면 세 경우가 모두 앱 수정 없이 동작한다 —
    /// 방 주소만 보낼 때(지금), 둘 다 보낼 때(전환 중), 사용자 주소만 보낼 때(전환 후).
    ///
    /// 아직 없는 주소를 구독해도 연결은 끊기지 않는다. 서버가 그런 구독을
    /// `/user/queue/errors`로 **메시지**를 보내 알릴 뿐이기 때문이다(백엔드 명세).
    ///
    /// 같은 참여가 양쪽으로 두 번 올 수 있는데, 그 중복은 받는 쪽(`RootFeature`)이 걸러낸다.
    public func memberJoinedEvents(
        inRooms roomIDs: [Room.ID]
    ) async throws -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error> {
        // 병렬로 건다. 순차로 걸면 아직 없는 주소가 구독 확정을 기다리는 동안(타임아웃)
        // 나머지 방 구독이 통째로 밀린다 — 실측에서 3.2초 밀렸다.
        // 한쪽이 실패해도 나머지는 살린다.
        let destinations = [RoomDestination.userRoomEvents]
            + roomIDs.map(RoomDestination.memberJoined(roomID:))

        let streams = await withTaskGroup(of: AsyncThrowingStream<STOMPEvent, any Error>?.self) { group in
            for destination in destinations {
                group.addTask { try? await client.subscribe(to: destination) }
            }
            var opened: [AsyncThrowingStream<STOMPEvent, any Error>] = []
            for await stream in group {
                if let stream {
                    opened.append(stream)
                }
            }
            return opened
        }

        // 하나도 못 걸었으면 오류로 알린다.
        // 빈 스트림을 돌려주면 받는 쪽이 "정상 종료"와 구별하지 못해, 다시 걸어야 할지 알 수 없다.
        guard !streams.isEmpty else {
            throw STOMPError.notConnected
        }

        return AsyncThrowingStream { continuation in
            let remaining = ActiveStreamCount(streams.count)
            let tasks = streams.map { stream in
                Task {
                    let failure = await forward(stream, to: continuation)
                    // 마지막 방의 구독까지 끝나야 합친 스트림도 끝난다.
                    if await remaining.finish(failure: failure) == 0 {
                        // 하나라도 오류로 끊겼으면 오류로 끝낸다. 정상 종료로 끝내면
                        // 받는 쪽이 "구독을 거뒀다"로 읽어 다시 걸지 않고, 참여 알림이
                        // 그대로 죽은 채 남는다.
                        if let failure = await remaining.failure {
                            continuation.finish(throwing: failure)
                        } else {
                            continuation.finish()
                        }
                    }
                }
            }
            // 소비가 끝나면 걸어 둔 구독이 전부 연쇄로 해제된다.
            continuation.onTermination = { _ in tasks.forEach { $0.cancel() } }
        }
    }

    /// 한 구독을 합친 스트림으로 흘린다. 끊긴 이유가 오류면 그 오류를 돌려준다.
    ///
    /// 여기서 바로 `finish(throwing:)`을 하지 않는 이유 — 방 하나가 끊겨도
    /// 나머지 방의 알림은 계속 받아야 한다. 오류는 마지막 하나까지 끝난 뒤에 알린다.
    private func forward(
        _ events: AsyncThrowingStream<STOMPEvent, any Error>,
        to continuation: AsyncThrowingStream<RoomMemberJoinedEvent, any Error>.Continuation
    ) async -> (any Error)? {
        do {
            for try await event in events {
                switch event {
                case let .message(body):
                    // 한 건이 깨져도 스트림을 죽이지 않는다 — 실시간이 통째로 멎는다.
                    guard let joined = decode(body) else { continue }
                    continuation.yield(.joined(joined))
                case .resumed:
                    continuation.yield(.resumed)
                }
            }
            return nil
        } catch is CancellationError {
            // 소비가 끝나서 거둔 것이다. 다시 걸 일이 아니다.
            return nil
        } catch {
            return error
        }
    }

    /// 서버가 REST와 같은 봉투로 보내는 것을 기본으로 두되, 봉투 없이 오는 형태도 받아 준다.
    func decode(_ body: Data) -> RoomMemberJoined? {
        if
            let envelope = try? decoder.decode(BaseResponseDTO<MemberJoinedPayloadDTO>.self, from: body),
            let payload = envelope.data {
            return payload.toDomain()
        }
        return (try? decoder.decode(MemberJoinedPayloadDTO.self, from: body))?.toDomain()
    }
}

/// 합친 스트림 중 몇 개가 아직 살아 있는지 세고, 끊긴 이유를 기억한다.
private actor ActiveStreamCount {

    private var count: Int

    /// 오류로 끊긴 구독이 있으면 그 중 처음 것. 전부 정상 종료면 nil이다.
    private(set) var failure: (any Error)?

    init(_ count: Int) {
        self.count = count
    }

    func finish(failure: (any Error)?) -> Int {
        if self.failure == nil {
            self.failure = failure
        }
        count -= 1
        return count
    }
}

/// 참여 이벤트 본문(`{ "room": { ... } }`).
struct MemberJoinedPayloadDTO: Decodable, Sendable {

    let room: RoomPayload

    struct RoomPayload: Decodable, Sendable {
        let id: Int64
        let title: String
        /// 들어온 사람. 빠져도 알림은 그대로 쓰므로 이벤트를 버리지 않는다(`RoomMemberJoined.userID` 참고).
        let userId: Int64?
        let userNickname: String
        let userProfileImageUrl: String?
    }

    func toDomain() -> RoomMemberJoined {
        RoomMemberJoined(
            roomID: room.id,
            roomTitle: room.title,
            userID: room.userId,
            nickname: room.userNickname,
            profileImageURL: room.userProfileImageUrl.flatMap(URL.init(string:))
        )
    }
}

/// 서버가 정한 구독 주소.
enum RoomDestination {

    /// 방 단위 주소. 방 개수만큼 구독을 걸어야 한다.
    static func memberJoined(roomID: Room.ID) -> String {
        "/topic/room/\(roomID)/member-joined"
    }

    /// 사용자 단위 주소. 구독 하나로 내 방 전부를 받는다.
    ///
    /// **이 문자열은 백엔드와 글자 하나까지 맞춰야 한다.** 서버가 다른 이름으로 열면
    /// 앱은 조용히 아무것도 받지 못한다(잘못된 주소 구독은 오류로 연결을 끊지 않기 때문).
    static let userRoomEvents = "/user/queue/room-events"
}
