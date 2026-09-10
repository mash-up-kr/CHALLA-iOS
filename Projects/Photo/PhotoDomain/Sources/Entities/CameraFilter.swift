import Foundation

public struct CameraFilter: Identifiable, Equatable, Sendable {

    public let name: String
    /// LUT(.cube) 파일 위치. 입힐 색이 없는 `none`은 내려받을 파일도 없어 nil이다.
    public let fileURL: URL?

    public var id: String {
        name
    }

    public init(name: String, fileURL: URL?) {
        self.name = name
        self.fileURL = fileURL
    }
}

public extension CameraFilter {

    /// 색을 입히지 않는 기본 모드. 서버 목록에는 없고 촬영 화면이 맨 앞에 고정으로 붙인다.
    static let none = CameraFilter(name: "None", fileURL: nil)

    var isNone: Bool {
        id == Self.none.id
    }

    static let previewFilters: [CameraFilter] = [
        "Black", "Gray", "Cold", "Blue", "Warm", "Old", "Forest", "Sky", "Green", "Soft"
    ].compactMap { name in
        URL(string: "https://preview.invalid/\(name.lowercased()).cube")
            .map { CameraFilter(name: name, fileURL: $0) }
    }
}
