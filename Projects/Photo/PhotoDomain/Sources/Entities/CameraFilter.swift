import Foundation

/// 서버가 내려주는 카메라 필터 한 개 — `GET /shoots/camera-filters` 응답 한 줄에 대응한다.
///
/// `name`이 식별자 겸 표시 이름이다 — 사진 업로드 완료 API도 이 값(`cameraFilterName`)으로 필터를 가리킨다.
/// 실제 색 변환 재료(.cube LUT)는 `fileURL`에서 내려받는다.
public struct CameraFilter: Identifiable, Equatable, Sendable {

    public let name: String
    /// LUT(.cube) 파일의 공개 URL. 만료되지 않아 내려받은 뒤 캐시해도 된다.
    public let fileURL: URL

    public var id: String {
        name
    }

    public init(name: String, fileURL: URL) {
        self.name = name
        self.fileURL = fileURL
    }
}

// MARK: - 프리뷰·데모 샘플

public extension CameraFilter {

    /// 화면 확인용 샘플. URL은 유효하지 않은 자리표시자다 — LUT 다운로드가 필요한 화면에는 쓰지 말 것.
    static let previewFilters: [CameraFilter] = [
        "Black", "Gray", "Cold", "Blue", "Warm", "Old", "Forest", "Sky", "Green", "Soft"
    ].compactMap { name in
        URL(string: "https://preview.invalid/\(name.lowercased()).cube")
            .map { CameraFilter(name: name, fileURL: $0) }
    }
}
