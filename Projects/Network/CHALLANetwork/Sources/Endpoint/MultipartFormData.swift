import Foundation

/// multipart/form-data 업로드의 파트 하나. Moya의 `MultipartFormData`에 대응한다.
public struct MultipartFormData: Sendable {

    /// 파트 데이터 (인코딩된 이미지 등).
    public let data: Data
    /// 폼 필드 이름 (`Content-Disposition`의 `name`).
    public let name: String
    /// 파일 이름 (`Content-Disposition`의 `filename`). 파일 파트일 때 지정.
    public let fileName: String?
    /// MIME 타입 (`Content-Type`). 예: `"image/jpeg"`.
    public let mimeType: String?

    public init(
        data: Data,
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil
    ) {
        self.data = data
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
}
