import Foundation

extension Endpoint {

    func asURLRequest(encoder: JSONEncoder) throws -> URLRequest {
        let url = path.isEmpty ? baseURL : baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        switch task {
        case .requestPlain:
            break

        case let .requestData(data):
            request.httpBody = data

        case let .requestParameters(parameters, encoding):
            request = try encoding.encode(request, with: parameters)

        case let .requestQueryItems(items):
            request = try encodeQueryItems(items, into: request)

        case let .requestJSONEncodable(value):
            request = try encodeJSON(value, into: request, using: encoder)

        case let .uploadMultipart(forms):
            request = encodeMultipart(forms, into: request)
        }

        return request
    }

    // MARK: - Task별 인코딩

    /// 순서와 키 반복을 보존해야 해서 `Parameters`(딕셔너리) 경로를 타지 않고 직접 인코딩한다.
    /// 이스케이프 규칙은 `URLEncoding`과 같은 것을 쓴다 — 케이스에 따라 인코딩 결과가 달라지면 안 된다.
    private func encodeQueryItems(_ items: [URLQueryItem], into request: URLRequest) throws -> URLRequest {
        var request = request
        guard !items.isEmpty else { return request }

        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest(reason: "쿼리 인코딩 대상 URL이 유효하지 않습니다.")
        }
        let encoded = items
            .map { "\(URLEncoding.escape($0.name))=\(URLEncoding.escape($0.value ?? ""))" }
            .joined(separator: "&")
        let existing = components.percentEncodedQuery.map { $0 + "&" } ?? ""
        components.percentEncodedQuery = existing + encoded
        guard let newURL = components.url else {
            throw NetworkError.invalidRequest(reason: "쿼리 병합 후 URL 생성에 실패했습니다.")
        }
        request.url = newURL
        return request
    }

    private func encodeJSON(
        _ value: any Encodable & Sendable,
        into request: URLRequest,
        using encoder: JSONEncoder
    ) throws -> URLRequest {
        var request = request
        do {
            request.httpBody = try encoder.encode(value)
        } catch {
            throw NetworkError.invalidRequest(reason: "JSON 인코딩에 실패했습니다: \(error.localizedDescription)")
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func encodeMultipart(_ forms: [MultipartFormData], into request: URLRequest) -> URLRequest {
        var request = request
        let boundary = "Boundary-\(UUID().uuidString)"
        let lineBreak = "\r\n"
        var body = Data()

        for form in forms {
            body.appendString("--\(boundary)\(lineBreak)")

            var disposition = "Content-Disposition: form-data; name=\"\(form.name)\""
            if let fileName = form.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.appendString(disposition + lineBreak)

            if let mimeType = form.mimeType {
                body.appendString("Content-Type: \(mimeType)\(lineBreak)")
            }
            body.appendString(lineBreak)

            body.append(form.data)
            body.appendString(lineBreak)
        }
        body.appendString("--\(boundary)--\(lineBreak)")

        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return request
    }
}

// MARK: - 내부 유틸

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
