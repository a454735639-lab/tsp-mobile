# TSP Mobile（iOS 原生客户端）

TSP 量化面板的 iPhone 客户端。**手机只做展示和操作，所有计算都在 NAS 上跑。**

## 这是什么

原生 SwiftUI 应用，直连 NAS 上 TSP 的 REST API（360 个接口中的核心子集）。
不是网页壳，没有 WebView —— 界面是真正用 SwiftUI 画的。

## 前提条件

1. **NAS 上 TSP 已运行**（容器 `tsp`，端口 3018）
2. **TSP 已设置登录密码**（未设置时任何人可访问全部接口）
3. **NAS 和手机在同一个 Tailscale 网络**
4. **一台 Mac + Xcode 15 或更新**（编译需要，Windows/Linux 做不了）

## 编译步骤

```bash
# 1. 把整个 TSPMobile 目录拷到 Mac
# 2. 双击 TSPMobile.xcodeproj 用 Xcode 打开
open TSPMobile.xcodeproj

# 3. 选自己的开发者 Team
#    Signing & Capabilities → Team 选你的 Apple ID
#    如需改 Bundle ID：PRODUCT_BUNDLE_IDENTIFIER 改成 com.你的名字.tspmobile

# 4. 真机运行
#    顶部选你的 iPhone → ⌘R
```

**命令行构建：**

```bash
xcodebuild -project TSPMobile.xcodeproj \
  -scheme TSPMobile \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/TSPMobile.xcarchive archive
```

然后 Xcode → Window → Organizer → 导出 IPA。

## 首次使用

1. 打开 App，输入服务器地址，格式 `http://<你的-NAS-IP>:3018`
   例如 Tailscale 地址 `http://100.64.0.1:3018`（用 `tailscale ip -4` 查你自己的）
2. 输入 TSP 密码（在 NAS 上设置的那个）
3. 登录后进入看板

## 已实现功能

| 页面 | 内容 |
|---|---|
| **看板** | 大盘指数、涨幅榜/跌幅榜、成交额榜 |
| **选股** | 全市场按市值/涨幅/换手率筛选，客户端排序 |
| **自选** | 自选列表 + 个股详情（K线走势、均线） |
| **设置** | 服务器地址、退出登录 |

## 关键实现细节

**认证是 Cookie，不是 Token。**
TSP 登录后返回 `Set-Cookie: tf_session=...; HttpOnly`，所以必须用
`URLSessionConfiguration.default`（它自带 `httpCookieStorage`），
不能用 `.ephemeral`，否则登录态存不住。

**两个接口的 `change_pct` 单位不一致（重要坑）。**

| 接口 | 格式 | 示例 |
|---|---|---|
| `/api/screener/market-snapshot`（个股） | **小数** | `0.0199` = 1.99% |
| `/api/overview/market`（指数） | **已是百分数** | `-0.8228` = -0.82% |

`Models.swift` 里 `StockQuote.pctPercent` 做 `*100`，
而 `MarketIndex.pctPercent` 直接返回原值。视图层只用 `pctPercent`，
不要自己再乘。搞错会把 -0.82% 显示成 -82%。

**涨跌颜色是红涨绿跌。**
按 A 股习惯，`TSPTheme.color(for:)` 统一处理，不要在各视图里硬编码颜色。

**自选接口是「对象包数组」。**
`/api/watchlist` 返回 `{"symbols": [{"symbol": "...", "name": "平安银行", ...}]}`，
外层是对象、里面才是数组。Swift 里要解一层 wrapper，不能直接当数组解。

**`market-snapshot` 不支持排序参数。**
服务端忽略 `sort`/`limit`，必须拉全量（约 5900 条）后在客户端排。
这是选股页的筛选逻辑放在 Swift 侧的原因。

## 目录结构

```
TSPMobile/
├── TSPMobile.xcodeproj/     # Xcode 工程
└── TSPMobile/
    ├── TSPMobileApp.swift   # 入口 + TabView
    ├── Models/
    │   └── Models.swift     # 数据模型（字段对齐真实 API）
    ├── Services/
    │   └── TSPClient.swift  # API 客户端（Cookie 会话）
    └── Views/
        ├── Theme.swift      # 配色 + 数字格式
        ├── LoginView.swift
        ├── DashboardView.swift
        ├── ScreenerView.swift
        ├── WatchlistView.swift
        └── SettingsView.swift
```

## 注意事项

- **`NSAllowsArbitraryLoads = YES`** 已在 Info.plist 配置里开启，
  因为 Tailscale 内网是 http 不是 https。如果将来改用 https 可以关掉。
- **没有做推送通知**。盘中告警推送需要 APNs 服务端，属于后续迭代。
- **只覆盖核心功能**。TSP 有 360 个接口（含回测、策略、模拟盘等），
  移动端全做不现实，优先做了看盘和选股这两个高频场景。
- **TSP 升级后接口可能变**。本项目基于 0.3.27 的 OpenAPI 快照，
  升级后若字段改名，需同步更新 `Models.swift`。
