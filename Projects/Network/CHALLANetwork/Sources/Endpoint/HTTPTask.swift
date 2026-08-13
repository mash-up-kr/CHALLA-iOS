import Foundation

/// 요청 본문·쿼리를 어떻게 구성할지 기술한다. CHALLA에서 실제로 필요한 케이스만 추렸다.
public enum HTTPTask: Sendable {

    /// 본문/쿼리 없이 전송 (주로 GET·DELETE).
    case requestPlain

    /// 미리 만들어 둔 `Data`를 본문으로 전송.
    case requestData(Data)

    /// 파라미터를 쿼리스트링으로 인코딩해 전송 (GET 쿼리).
    case requestParameters(parameters: Parameters, encoding: any ParameterEncoding)

    /// 같은 키가 반복되는 배열 쿼리로 전송 (예: `?status=A&status=B`).
    /// `Parameters`는 딕셔너리라 키 반복을 표현할 수 없어 케이스를 분리했다.
    /// 키가 전부 다른 쿼리는 `requestParameters`를 쓴다.
    case requestQueryItems([URLQueryItem])

    /// `Encodable` 모델을 JSON 본문으로 인코딩해 전송 (POST/PUT).
    case requestJSONEncodable(any Encodable & Sendable)

    /// multipart/form-data 업로드 (사진 업로드 등).
    case uploadMultipart([MultipartFormData])
}
