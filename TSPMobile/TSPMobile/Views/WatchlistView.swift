import SwiftUI

/// 自选 + 个股 K 线详情。
struct WatchlistView: View {
    @EnvironmentObject private var client: TSPClient
    @State private var items: [WatchlistItem] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error {
                    VStack {
                        ErrorBanner(message: error).padding()
                        Spacer()
                    }
                } else if items.isEmpty && !loading {
                    // 不用 ContentUnavailableView：那是 iOS 17+ API，
                    // 而本工程最低支持 iOS 16，手写等价布局更保险。
                    VStack(spacing: 10) {
                        Image(systemName: "star")
                            .font(.system(size: 44))
                            .foregroundStyle(.tertiary)
                        Text("自选为空").font(.headline)
                        Text("在 TSP 网页端添加自选后，这里会同步显示")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                StockDetailView(symbol: item.symbol, name: item.name ?? "")
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? item.symbol)
                                        .font(.subheadline.weight(.medium))
                                    Text(item.symbol)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("自选")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if loading && items.isEmpty { ProgressView() }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            items = try await client.fetchWatchlist()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 个股详情：K 线走势 + 均线。
struct StockDetailView: View {
    @EnvironmentObject private var client: TSPClient
    let symbol: String
    let name: String

    @State private var rows: [KlineRow] = []
    @State private var loading = false
    @State private var error: String?

    private var last: KlineRow? { rows.last }
    private var prevClose: Double? { rows.count >= 2 ? rows[rows.count - 2].close : nil }

    private var changePct: Double? {
        guard let last, let prev = prevClose, prev != 0 else { return nil }
        return (last.close / prev - 1) * 100
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error { ErrorBanner(message: error) }

                // 头部报价
                if let last {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(TSPTheme.priceText(last.close))
                            .font(.system(size: 34, weight: .bold).monospacedDigit())
                            .foregroundStyle(TSPTheme.color(for: changePct))
                        Text(TSPTheme.pctText(changePct))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(TSPTheme.color(for: changePct))
                        HStack(spacing: 16) {
                            metric("最高", TSPTheme.priceText(last.high))
                            metric("最低", TSPTheme.priceText(last.low))
                            metric("开盘", TSPTheme.priceText(last.open))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                }

                // K 线图
                if !rows.isEmpty {
                    SectionCard(title: "近 \(rows.count) 日走势") {
                        KlineChart(rows: rows)
                            .frame(height: 200)
                    }
                    .padding(.horizontal, 16)

                    SectionCard(title: "均线") {
                        HStack(spacing: 20) {
                            maItem("MA5", last?.ma5, TSPTheme.accent)
                            maItem("MA10", last?.ma10, .orange)
                            maItem("MA20", last?.ma20, .blue)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(name.isEmpty ? symbol : name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit())
        }
    }

    private func maItem(_ label: String, _ value: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(color)
            Text(TSPTheme.priceText(value)).font(.caption.monospacedDigit())
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            rows = try await client.fetchKline(symbol: symbol, days: 120).rows
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 极简收盘价折线图。用 Path 手绘，避免引入 Swift Charts 之外的依赖。
struct KlineChart: View {
    let rows: [KlineRow]

    var body: some View {
        GeometryReader { geo in
            let closes = rows.map(\.close)
            let minV = closes.min() ?? 0
            let maxV = closes.max() ?? 1
            let span = max(maxV - minV, 0.01)

            Path { path in
                for (i, c) in closes.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(closes.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((c - minV) / span))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(TSPTheme.accent, lineWidth: 1.6)
        }
    }
}
