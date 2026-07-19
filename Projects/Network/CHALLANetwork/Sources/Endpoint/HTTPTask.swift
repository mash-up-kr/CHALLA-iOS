import Foundation

/// 요청 본문·쿼리를 어떻게 구성할지 기술한다. Moya의 `Task`에 대응하되,
/// CHALLA에서 실제로 필요한 케이스만 추린 축소판이다.
///
/// 모든 연관값이 `Sendable`이라 `HTTPTask`·`Endpoint`도 `Sendable`이다.
public enum HTTPTask: Sendable {

    /// 본문/쿼리 없이 전송 (주로 GET·DELETE).
    case requestPlain

    /// 미리 만들어 둔 `Data`를 본문으로 전송.
    case requestData(Data)

    /// 파라미터를 쿼리스트링으로 인코딩해 전송 (GET 쿼리).
    case requestParameters(parameters: Parameters, encoding: any ParameterEncoding)

    /// `Encodable` 모델을 JSON 본문으로 인코딩해 전송 (POST/PUT).
    case requestJSONEncodable(any Encodable & Sendable)

    /// multipart/form-data 업로드 (사진 업로드 등).
    case uploadMultipart([MultipartFormData])
}
