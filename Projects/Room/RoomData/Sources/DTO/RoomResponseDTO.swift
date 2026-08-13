import Foundation

/// 서버의 방 상태 표기. 여기 없는 값이 오면 그 응답은 디코딩에 실패한다.
/// 의도된 동작이다 — 서버에 새 상태가 추가되면 그 방을 어느 섹션에 어떤 문구로 보여줄지
/// 앱이 새로 정해야 하므로, 아무 상태로나 잘못 보여주는 것보다 오류로 드러나는 쪽이 낫다.
enum RoomStatusDTO: String, Decodable, Sendable, CaseIterable {
    case shooting = "SHOOTING"
    case printPending = "PHOTO_PRINT_PENDING"
    case printCompleted = "PHOTO_PRINT_COMPLETED"
}

/// `GET /api/v1/rooms` 응답 페이로드 (`BaseResponseDTO.data`).
///
/// 날짜가 `String`인 이유 — 서버가 타임존 없는 표기("2026-08-11T12:34:56")를 줘서
/// 디코더 기본 전략으로 `Date`를 못 만든다. 공용 디코더에 날짜 규칙을 설정하면
/// 그 디코더를 함께 쓰는 유저·인증 등 다른 도메인의 API 디코딩까지 바뀌므로,
/// 문자열로 받고 방 매핑 안에서만 파싱한다.
struct RoomListResponseDTO: Decodable, Sendable {

    let rooms: [RoomDTO]

    struct RoomDTO: Decodable, Sendable {
        let id: Int64
        let status: RoomStatusDTO
        let title: String
        let memberCount: Int
        let totalPhotoCount: Int
        let remainedPhotoCount: Int
        let thumbnailImageUrls: [String]
        let photoPrintCompletedAt: String?
        let createdAt: String
        let expiresAt: String
    }
}

/// `GET /api/v1/rooms/{id}` 응답 페이로드 (`BaseResponseDTO.data`).
struct RoomDetailResponseDTO: Decodable, Sendable {

    let room: Payload

    struct Payload: Decodable, Sendable {
        /// 서버 스키마상 이 응답의 id만 nullable이다 (목록 응답은 필수). 매핑이 요청 id로 메꾼다.
        /// TODO: 백엔드 확인 — 상세 응답의 id가 실제로 null일 수 있는지, 스키마 실수라면 필수로 교정 요청.
        let id: Int64?
        let title: String
        let status: RoomStatusDTO
        let totalPhotoCount: Int
        let remainedPhotoCount: Int
        let invitationCode: String
        let photoPrintCompletedAt: String?
        let createdAt: String
        let expiresAt: String
    }
}

/// `GET /api/v1/rooms/{id}/users` 응답 페이로드.
struct RoomMembersResponseDTO: Decodable, Sendable {

    let users: [MemberDTO]

    struct MemberDTO: Decodable, Sendable {
        let id: Int64
        let nickname: String?
        let profileImageUrl: String?
    }
}

/// `POST /rooms` · `POST /rooms/join` 응답 페이로드. 둘 다 `{ room: { id } }` 하나뿐이라 공유한다.
/// 방 전체는 안 온다 — 저장소가 목록 재조회로 카드를 채운다 (`DefaultRoomRepository` 참고).
struct RoomIDResponseDTO: Decodable, Sendable {

    let room: Payload

    struct Payload: Decodable, Sendable {
        let id: Int64
    }
}
