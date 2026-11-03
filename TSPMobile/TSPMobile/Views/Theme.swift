import SwiftUI

/// 全局配色。
///
/// 涨跌颜色遵循 A 股习惯：**涨红跌绿**，与欧美市场相反。
/// 这里集中定义，避免各视图各写一套导致不一致。
enum TSPTheme {

    // MARK: 品牌色（取自 TSP 网页的 theme-color #8B5CF6）
    static let accent = Color(red: 0.545, green: 0.361, blue: 0.965)

    // MARK: 涨跌色
    /// 涨 —— 红
    static let up = Color(red: 0.878, green: 0.153, blue: 0.153)
    /// 跌 —— 绿
    static let down = Color(red: 0.078, green: 0.671, blue: 0.290)
    /// 平盘
    static let flat = Color.secondary

    static func color(for changePct: Double?) -> Color {
        guard let v = changePct else { return flat }
        if v > 0 { return up }
        if v < 0 { return down }
        return flat
    }

    // MARK: 数字格式

    /// 涨跌幅：+1.99% / -0.82%
    static func pctText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.2f%%", value)
    }

    /// 价格：保留两位
    static func priceText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    /// 金额：亿 / 万
    static func amountText(_ yi: Double?) -> String {
        guard let yi else { return "—" }
        if yi >= 1 { return String(format: "%.2f亿", yi) }
        return String(format: "%.0f万", yi * 1e4)
    }

    /// 大盘指数用更高精度（3608.098）
    static func indexText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }
}
