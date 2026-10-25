import Foundation

enum HTTPError: LocalizedError {
    case noResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .noResponse: return "服务器无响应"
        case .http(let code, let body):
            let preview = body.isEmpty ? "" : String(body.prefix(300))
            return "HTTP \(code): \(preview)"
        }
    }
}

/// 极简 URLSession 封装:返回 (Data, HTTP 状态码),不在 4xx/5xx 上抛错,
/// 让调用方按业务判断(登录流程需要区分 code 字段与 HTTP 状态)。
struct APIClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: cfg)
    }

    func request(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        json: [String: Any]? = nil,
        form: [String: String]? = nil
    ) async throws -> (data: Data, status: Int) {
        // 多段 path 直接字符串拼接(不能用 appendingPathComponent,会把 "/" 转义)。
        var comps = URLComponents(string: baseURL.absoluteString + path)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw HTTPError.noResponse }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let json {
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        if let form {
            var fc = URLComponents()
            fc.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
            req.httpBody = fc.percentEncodedQuery?.data(using: .utf8)
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}
