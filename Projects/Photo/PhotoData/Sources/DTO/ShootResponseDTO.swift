import Foundation

/// `GET /shoots/camera-filters` 응답 페이로드 (`BaseResponseDTO.data`).
struct CameraFiltersResponseDTO: Decodable, Sendable {

    let shoot: Payload

    struct Payload: Decodable, Sendable {
        let cameraFilters: [CameraFilterDTO]
    }

    struct CameraFilterDTO: Decodable, Sendable {
        let name: String
        let fileUrl: String
    }
}
