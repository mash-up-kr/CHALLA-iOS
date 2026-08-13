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
            request = try URLEncoding.default.encode(request, with: items)

        case let .requestJSONEncodable(value):
            request = try encodeJSON(value, into: request, using: encoder)

        case let .uploadMultipart(forms):
            request = encodeMultipart(forms, into: request)
        }

        return request
    }

    // MARK: - Task별 인코딩

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
