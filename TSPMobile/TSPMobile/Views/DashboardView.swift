import SwiftUI

/// 看板：指数卡片 + 涨跌榜 + 成交额榜。
struct DashboardView: View {
    @EnvironmentObject private var client: TSPClient
    @State private var overview: MarketOverview?
    @State private var quotes: [StockQuote] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error {
                        ErrorBanner(message: error)
                    }

                    // 指数
                    if let indices = overview?.indices, !indices.isEmpty {
                        SectionCard(title: "大盘指数") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                                      spacing: 12) {
                                ForEach(indices) { idx in
                                    IndexTile(index: idx)
                                }
                            }
                        }
                    }

                    // 涨幅榜
                    if !quotes.isEmpty {
                        SectionCard(title: "涨幅榜 TOP 10") {
                            RankList(rows: Array(quotes.prefix(10)))
                        }

                        SectionCard(title: "跌幅榜 TOP 10") {
                            RankList(rows: Array(quotes.suffix(10).reversed()))
                        }

                        SectionCard(title: "成交额榜 TOP 10") {
                            RankList(rows: Array(quotes.prefix(10)),
                                     valueStyle: .amount)
                        }
                    }

                    if loading {
                        ProgressView("加载中…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(16)
            }
            .navigationTitle("看板")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { if overview == nil { await load() } }
            .toolbar {
                if let asOf = overview?.asOf {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(asOf).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let ov = client.fetchOverview()
            async let snap = client.fetchSnapshot()
            let (o, s) = try await (ov, snap)
            overview = o

            // 服务端不保证排序，这里按涨跌幅排好
            let sorted = s.rows
                .filter { $0.changePct != nil }
                .sorted { ($0.changePct ?? 0) > ($1.changePct ?? 0) }
            quotes = sorted
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - 指数卡

struct IndexTile: View {
    let index: MarketIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(TSPTheme.indexText(index.lastPrice))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(TSPTheme.color(for: index.pctPercent))
            Text(TSPTheme.pctText(index.pctPercent))
                .font(.caption.monospacedDigit())
                .foregroundStyle(TSPTheme.color(for: index.pctPercent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 榜单

struct RankList: View {
    enum ValueStyle { case pct, amount }
    let rows: [StockQuote]
    var valueStyle: ValueStyle = .pct

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, q in
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 18, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.name).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text(q.shortCode).font(.caption2).foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TSPTheme.priceText(q.close))
                            .font(.subheadline.monospacedDigit())
                        Text(valueText(for: q))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(valueColor(for: q))
                    }
                }
                .padding(.vertical, 9)

                if i < rows.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func valueText(for q: StockQuote) -> String {
        switch valueStyle {
        case .pct:    return TSPTheme.pctText(q.pctPercent)
        case .amount: return TSPTheme.amountText(q.amountYi)
        }
    }

    private func valueColor(for q: StockQuote) -> Color {
        valueStyle == .pct ? TSPTheme.color(for: q.pctPercent) : .secondary
    }
}

// MARK: - 通用容器

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message).font(.footnote)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
