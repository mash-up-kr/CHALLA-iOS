import CHALLANetwork
import Foundation
import os
import RoomDomain

/// `/user/queue/member-joined` 구독. 프레임 본문을 도메인 이벤트로 바꿔 흘린다.
public struct RoomEventSubscriber: RoomEventStreaming {

    private let client: any STOMPClienting
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.challa.room", category: "RoomEvents")

    public init(client: any STOMPClienting) {
        self.client = client
    }

    /// 사용자 단위 주소 하나로 내 방 전부의 참여 이벤트를 받는다. 방 개수와 무관하다.
    public func memberJoinedEvents(
        inRooms _: [Room.ID]
    ) async throws -> AsyncThrowingStream<RoomMemberJoinedEvent, any Error> {
        // 구독이 확정된 뒤에야 리턴한다. 실패하면 그대로 던져 받는 쪽이 다시 걸게 한다 —
        // 빈 스트림을 돌려주면 "정상 종료"와 구별하지 못해 다시 걸어야 할지 알 수 없다.
        let events = try await client.subscribe(to: RoomDestination.userMemberJoined)

        return AsyncThrowingStream { continuation in
            let task = Task {
                // 오류로 끊긴 것을 정상 종료로 끝내면 받는 쪽이 "구독을 거뒀다"로 읽어
                // 다시 걸지 않고, 참여 알림이 죽은 채 남는다.
                if let failure = await forward(events, to: continuation) {
                    continuation.finish(throwing: failure)
                } else {
                    continuation.finish()
                }
            }
            // 소비가 끝나면 걸어 둔 구독도 함께 해제된다.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 구독을 도메인 스트림으로 흘린다. 끊긴 이유가 오류면 그 오류를 돌려준다.
    private func forward(
        _ events: AsyncThrowingStream<STOMPEvent, any Error>,
        to continuation: AsyncThrowingStream<RoomMemberJoinedEvent, any Error>.Continuation
    ) async -> (any Error)? {
        do {
            for try await event in events {
                switch event {
                case let .message(body):
                    // 한 건이 깨져도 스트림을 죽이지 않는다 — 실시간이 통째로 멎는다.
                    // 다만 조용히 버리지는 않는다. 로그가 없으면 "서버가 안 보냈다"와
                    // "받았는데 못 읽었다"를 구별할 수 없다.
                    guard let joined = decode(body) else {
                        let text = String(bytes: body, encoding: .utf8) ?? "<binary>"
                        logger.error("참여 이벤트를 해석하지 못했다: \(text, privacy: .public)")
                        continue
                    }
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

    /// 사용자 단위 주소. 구독 하나로 내 방 전부를 받는다.
    ///
    /// 백엔드와 글자 하나까지 맞아야 한다 — 틀리면 구독은 성공한 것처럼 보이고
    /// 아무것도 오지 않는다.
    static let userMemberJoined = "/user/queue/member-joined"
}
