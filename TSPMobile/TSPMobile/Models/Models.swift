import Foundation

// MARK: - 指数

struct MarketIndex: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let lastPrice: Double
    /// 注意：TSP 返回的是小数（0.0199 = 1.99%），不是百分数
    let changePct: Double
    let changeAmount: Double

    enum CodingKeys: String, CodingKey {
        case symbol, name
        case lastPrice = "last_price"
        case changePct = "change_pct"
        case changeAmount = "change_amount"
    }

    /// 注意：`/api/overview/market` 返回的 change_pct **已经是百分数**
    /// （如 -0.8228 表示 -0.82%），与 `/api/screener/market-snapshot`
    /// 的小数格式不同。这两个接口单位不一致，不要统一乘 100。
    var pctPercent: Double { changePct }
}

// MARK: - 行情快照

struct StockQuote: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let close: Double?
    let changePct: Double?
    let amount: Double?
    let volume: Double?
    let turnoverRate: Double?
    let volRatio5d: Double?
    let marketCap: Double?
    let floatMarketCap: Double?
    let consecutiveLimitUps: Int?

    enum CodingKeys: String, CodingKey {
        case symbol, name, close, amount, volume
        case changePct = "change_pct"
        case turnoverRate = "turnover_rate"
        case volRatio5d = "vol_ratio_5d"
        case marketCap = "market_cap"
        case floatMarketCap = "float_market_cap"
        case consecutiveLimitUps = "consecutive_limit_ups"
    }

    var pctPercent: Double? { changePct.map { $0 * 100 } }
    var amountYi: Double? { amount.map { $0 / 1e8 } }
    var capYi: Double? { marketCap.map { $0 / 1e8 } }

    /// 六位代码，去掉 .SH/.SZ 后缀
    var shortCode: String {
        String(symbol.split(separator: ".").first ?? "")
    }
}

struct MarketSnapshot: Codable {
    let asOf: String
    let rows: [StockQuote]

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case rows
    }
}

// MARK: - 看板总览

struct QuoteStatus: Codable {
    let enabled: Bool
    let running: Bool
    let realtimeAllowed: Bool
    let marketPhase: String?
    let isTradingHours: Bool

    enum CodingKeys: String, CodingKey {
        case enabled, running
        case realtimeAllowed = "realtime_allowed"
        case marketPhase = "market_phase"
        case isTradingHours = "is_trading_hours"
    }
}

struct MarketOverview: Codable {
    let asOf: String
    let quoteStatus: QuoteStatus?
    let indices: [MarketIndex]

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case quoteStatus = "quote_status"
        case indices
    }
}

// MARK: - K 线

struct KlineRow: Codable, Identifiable {
    var id: String { date }
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let amount: Double?
    let ma5: Double?
    let ma10: Double?
    let ma20: Double?
}

struct KlineResponse: Codable {
    let symbol: String
    let name: String?
    let rows: [KlineRow]
}

// MARK: - 自选

/// `/api/watchlist` 返回的是对象数组，形如：
/// `[{"symbol":"000001.SZ","name":"平安银行","note":"","group_ids":[],"added_at":"..."}]`
struct WatchlistItem: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String?
    let note: String?
    let groupIds: [Int]?
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case symbol, name, note
        case groupIds = "group_ids"
        case addedAt = "added_at"
    }
}

struct WatchlistGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
    }
}

// MARK: - 市场情绪

struct MarketRegime: Codable {
    let row: RegimeRow?
}

struct RegimeRow: Codable {
    let date: String?
    let state: String?
    let score: Double?
    let mainline: String?
}

// MARK: - 认证

struct AuthStatus: Codable {
    let configured: Bool
    let authenticated: Bool
}

struct LoginResponse: Codable {
    let ok: Bool
    let authenticated: Bool?
}
