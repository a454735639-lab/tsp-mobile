import SwiftUI

/// 选股：本地对全市场快照做筛选（服务端 snapshot 不支持排序参数，需客户端处理）。
struct ScreenerView: View {
    @EnvironmentObject private var client: TSPClient
    @State private var all: [StockQuote] = []
    @State private var loading = false
    @State private var error: String?

    // 筛选条件
    @State private var minCapYi: Double = 30
    @State private var maxPct: Double = 9.5
    @State private var minTurnover: Double = 1.0
    @State private var sortByAmount = true

    var body: some View {
        NavigationStack {
            List {
                Section("筛选条件") {
                    Stepper("流通市值 ≥ \(Int(minCapYi)) 亿", value: $minCapYi, in: 0...2000, step: 10)
                    HStack {
                        Text("涨幅上限")
                        Spacer()
                        Text(String(format: "%.1f%%", maxPct)).foregroundStyle(.secondary)
                    }
                    Slider(value: $maxPct, in: 0...10, step: 0.5)
                    HStack {
                        Text("换手率 ≥")
                        Spacer()
                        Text(String(format: "%.1f%%", minTurnover)).foregroundStyle(.secondary)
                    }
                    Slider(value: $minTurnover, in: 0...20, step: 0.5)
                    Toggle("按成交额排序", isOn: $sortByAmount)
                }

                if let error {
                    Section { ErrorBanner(message: error) }
                }

                Section("结果（\(filtered.count) 只）") {
                    ForEach(filtered.prefix(50)) { q in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.name).font(.subheadline.weight(.medium))
                                Text(q.shortCode).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(TSPTheme.priceText(q.close))
                                    .font(.subheadline.monospacedDigit())
                                Text(TSPTheme.pctText(q.pctPercent))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(TSPTheme.color(for: q.pctPercent))
                            }
                        }
                    }
                }
            }
            .navigationTitle("选股")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task { if all.isEmpty { await load() } }
            .overlay {
                if loading && all.isEmpty {
                    ProgressView("拉取全市场数据…")
                }
            }
        }
    }

    /// 客户端筛选 + 排序
    private var filtered: [StockQuote] {
        let hit = all.filter { q in
            let capOK = (q.capYi ?? 0) >= minCapYi
            let pctOK = (q.pctPercent ?? 0) <= maxPct
            let toOK = (q.turnoverRate ?? 0) >= minTurnover
            return capOK && pctOK && toOK
        }
        if sortByAmount {
            return hit.sorted { ($0.amount ?? 0) > ($1.amount ?? 0) }
        }
        return hit.sorted { ($0.pctPercent ?? 0) > ($1.pctPercent ?? 0) }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            all = try await client.fetchSnapshot().rows
        } catch {
            self.error = error.localizedDescription
        }
    }
}
