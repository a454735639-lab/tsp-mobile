import Foundation

/// TSP 的 API 客户端。
///
/// 认证方式：TSP 用 `tf_session` Cookie（HttpOnly，30 天有效），
/// 所以必须让 `URLSession` 自己管理 cookie 存储，登录后自动带上。
/// 这也是为什么这里用 `URLSessionConfiguration.default`（自带
/// `httpCookieStorage`）而不是 `.ephemeral`。
@MainActor
final class TSPClient: ObservableObject {

    /// 连接配置。默认指向 Tailscale 内网地址，可在设置页修改。
    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Self.baseURLKey) }
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var lastError: String?

    private static let baseURLKey = "tsp.baseURL"
    private let session: URLSession

    init() {
        // 不硬编码任何内网地址：首次启动留空，让用户在登录页填。
        // 这样仓库公开时不会泄露 Tailscale IP。
        baseURL = UserDefaults.standard.string(forKey: Self.baseURLKey) ?? ""

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 90
        // Cookie 由系统 cookieStorage 统一管理，登录态才能跨请求保持
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        session = URLSession(configuration: cfg)
    }

    // MARK: - 基础请求

    private func makeRequest(_ path: String, method: String = "GET") throws -> URLRequest {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.emptyBaseURL }
        guard let url = URL(string: trimmed.trimmedTrailingSlash + path),
              url.scheme != nil, url.host != nil else {
            throw APIError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    /// 统一请求入口：解码 JSON，并把 401 转成明确的未登录错误。
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        as type: T.Type
    ) async throws -> T {
        var req = try makeRequest(path, method: method)
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noResponse }

        if http.statusCode == 401 {
            isAuthenticated = false
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            // TSP 的错误体是 FastAPI 的 {detail: ...}
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, snippet)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - 认证

    func checkAuthStatus() async {
        do {
            let status = try await request("/api/auth/status", as: AuthStatus.self)
            isAuthenticated = status.authenticated
        } catch {
            isAuthenticated = false
            lastError = error.localizedDescription
        }
    }

    func login(password: String) async throws {
        struct Body: Encodable { let password: String }
        _ = try await request("/api/auth/login", method: "POST",
                              body: Body(password: password),
                              as: LoginResponse.self)
        isAuthenticated = true
        lastError = nil
    }

    func logout() async {
        _ = try? await request("/api/auth/logout", method: "POST", as: LoginResponse.self)
        isAuthenticated = false
        // 清掉本地 cookie，避免下次带着失效会话
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies where c.name == "tf_session" {
                HTTPCookieStorage.shared.deleteCookie(c)
            }
        }
    }

    // MARK: - 数据

    func fetchOverview() async throws -> MarketOverview {
        try await request("/api/overview/market", as: MarketOverview.self)
    }

    func fetchSnapshot() async throws -> MarketSnapshot {
        try await request("/api/screener/market-snapshot", as: MarketSnapshot.self)
    }

    func fetchKline(symbol: String, days: Int = 120) async throws -> KlineResponse {
        try await request("/api/kline/daily?symbol=\(symbol)&days=\(days)",
                          as: KlineResponse.self)
    }

    /// `/api/watchlist` 返回 `{"symbols": [{...}]}` —— 外层是对象，
    /// 里面才是数组，且条目自带 name，不需要再补查。
    func fetchWatchlist() async throws -> [WatchlistItem] {
        struct Wrapper: Decodable { let symbols: [WatchlistItem] }
        return try await request("/api/watchlist", as: Wrapper.self).symbols
    }

    func fetchRegime() async throws -> MarketRegime {
        try await request("/api/regime/latest", as: MarketRegime.self)
    }
}

// MARK: - 错误

enum APIError: LocalizedError {
    case emptyBaseURL
    case badURL
    case noResponse
    case unauthorized
    case http(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .emptyBaseURL:      return "请先填写服务器地址，例如 http://100.64.0.1:3018"
        case .badURL:            return "地址无效，需包含 http:// 或 https:// 前缀"
        case .noResponse:        return "服务器无响应"
        case .unauthorized:      return "未登录或登录已过期"
        case .http(let c, let s): return "请求失败（HTTP \(c)）\(s.isEmpty ? "" : "：\(s)")"
        case .decoding(let s):   return "数据解析失败：\(s)"
        }
    }
}

// MARK: - 辅助

/// 让任意 Encodable 都能塞进泛型请求体。
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeClosure = { try wrapped.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

private extension String {
    var trimmedTrailingSlash: String {
        hasSuffix("/") ? String(dropLast()) : self
    }
}
