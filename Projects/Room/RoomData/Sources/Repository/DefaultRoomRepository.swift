import CHALLANetwork
import Foundation
import RoomDomain

/// `RoomRepository`의 실서버 구현. 요청 → 껍데기 언랩 → 도메인 변환 → 실패 정규화가 전부다.
public struct DefaultRoomRepository: RoomRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func rooms() async throws -> [RoomCard] {
        do {
            let response = try await client.request(
                RoomEndpoint.rooms(statuses: RoomStatusDTO.allCases), // 홈은 두 섹션을 한 화면에 그려 전체를 받는다
                as: BaseResponseDTO<RoomListResponseDTO>.self
            )
            return try response.unwrap().rooms.map { try $0.toDomain() }
        } catch {
            throw RoomError.normalized(error)
        }
    }

    public func createRoom(_ draft: RoomDraft) async throws -> RoomCard {
        do {
            let response = try await client.request(
                RoomEndpoint.create(
                    CreateRoomRequestDTO(title: draft.name, totalPhotoCount: draft.shotCount.rawValue)
                ),
                as: BaseResponseDTO<RoomIDResponseDTO>.self
            )
            return try await card(withID: response.unwrap().room.id)
        } catch {
            throw RoomError.normalized(error)
        }
    }

    public func joinRoom(inviteCode: String) async throws -> RoomCard {
        do {
            let response = try await client.request(
                RoomEndpoint.join(JoinRoomRequestDTO(invitationCode: inviteCode)),
                as: BaseResponseDTO<RoomIDResponseDTO>.self
            )
            return try await card(withID: response.unwrap().room.id)
        } catch {
            throw RoomError.normalized(error)
        }
    }

    public func roomInfo(id: Room.ID) async throws -> (room: Room, invitationCode: String) {
        do {
            let response = try await client.request(
                RoomEndpoint.detail(id: id),
                as: BaseResponseDTO<RoomDetailResponseDTO>.self
            )
            return try response.unwrap().room.toDomain(requestedID: id)
        } catch {
            throw RoomError.normalized(error)
        }
    }

    public func members(roomID: Room.ID) async throws -> [RoomMember] {
        do {
            let response = try await client.request(
                RoomEndpoint.members(roomID: roomID),
                as: BaseResponseDTO<RoomMembersResponseDTO>.self
            )
            return try response.unwrap().users.map { $0.toDomain() }
        } catch {
            throw RoomError.normalized(error)
        }
    }

    // MARK: - 카드 채우기

    /// 생성·입장 응답은 `{ id }`뿐인데 계약은 카드를 요구한다 — 목록을 다시 받아 그 id의 카드를 찾는다.
    /// TODO: 백엔드가 생성·입장 응답에 방 전체를 실어주면 이 재조회를 지운다 (#54 백엔드 확인 항목).
    private func card(withID id: Int64) async throws -> RoomCard {
        guard let card = try await rooms().first(where: { $0.id == id }) else {
            // 방금 만들었거나 입장한 방이 목록에 없다 — 서버 계약 위반이라 정해진 케이스가 없다.
            throw RoomError.unknown
        }
        return card
    }
}
