/**
 * 模拟 Swift 客户端的完整调用链，验证：
 *  1. 登录（Cookie 会话）
 *  2. 看板（overview + snapshot）
 *  3. 选股（客户端筛选）
 *  4. 自选（symbols + 名称映射）
 *  5. K 线
 * 目的是在拿到 Mac 编译前，先确认 API 契约与 Swift 模型一致。
 */
const BASE = "http://100.66.1.2:3018";
let cookie = "";

async function call(path, opts = {}) {
  const res = await fetch(BASE + path, {
    ...opts,
    headers: {
      Accept: "application/json",
      ...(opts.body ? { "Content-Type": "application/json" } : {}),
      ...(cookie ? { Cookie: cookie } : {}),
    },
  });
  const setCookie = res.headers.get("set-cookie");
  if (setCookie) cookie = setCookie.split(";")[0];
  const text = await res.text();
  if (!res.ok) throw new Error(`${path} HTTP ${res.status}: ${text.slice(0, 120)}`);
  return text ? JSON.parse(text) : null;
}

const ok = (label, cond, extra = "") =>
  console.log(`${cond ? "PASS" : "FAIL"}  ${label}${extra ? "  " + extra : ""}`);

(async () => {
  // 1. 登录
  const login = await call("/api/auth/login", {
    method: "POST",
    body: JSON.stringify({ password: "quant2026" }),
  });
  ok("登录", login?.authenticated === true, `cookie=${cookie ? "已获取" : "无"}`);

  // 2. 看板
  const ov = await call("/api/overview/market");
  ok("看板 overview", Array.isArray(ov?.indices) && ov.indices.length > 0,
     `指数 ${ov?.indices?.length} 个`);

  const first = ov.indices[0];
  // Swift 模型要求的字段
  const ovFields = ["symbol", "name", "last_price", "change_pct", "change_amount"];
  const missing = ovFields.filter((f) => !(f in first));
  ok("overview 字段对齐", missing.length === 0, missing.length ? "缺: " + missing : "");

  // 3. 全市场快照
  const snap = await call("/api/screener/market-snapshot");
  ok("快照", Array.isArray(snap?.rows), `${snap?.rows?.length} 行`);

  const q = snap.rows.find((r) => r.symbol === "000001.SZ");
  const qFields = ["symbol", "name", "close", "change_pct", "turnover_rate", "market_cap"];
  const qMissing = qFields.filter((f) => !(f in q));
  ok("快照字段对齐", qMissing.length === 0, qMissing.length ? "缺: " + qMissing : "");

  // 关键：确认 change_pct 是小数（Swift 里要 *100）
  ok("个股 change_pct 为小数", Math.abs(q.change_pct) < 1,
     `值=${q.change_pct} → ${(q.change_pct * 100).toFixed(2)}%`);

  // 指数接口的单位不同，单独断言
  // 关键区分：指数 -0.82 就是 -0.82%，若再乘 100 会变成 -82%，明显错误
  ok("指数 change_pct 已是百分数", Math.abs(first.change_pct) < 10 && Math.abs(first.change_pct) > 0.01,
     `值=${first.change_pct} → 直接展示 ${first.change_pct.toFixed(2)}%（乘100则错为 ${(first.change_pct * 100).toFixed(0)}%）`);

  // 4. 选股（复现 Swift 的筛选逻辑）
  const hit = snap.rows.filter((r) => {
    const capYi = (r.market_cap ?? 0) / 1e8;
    const pct = (r.change_pct ?? 0) * 100;
    const to = r.turnover_rate ?? 0;
    return capYi >= 30 && pct <= 9.5 && to >= 1.0;
  });
  ok("选股筛选", hit.length > 0, `命中 ${hit.length} 只`);

  // 5. 自选
  const wl = await call("/api/watchlist");
  // 实际结构是 {"symbols":[{symbol,name,...}]}，不是裸数组
  const wlArr = Array.isArray(wl?.symbols) ? wl.symbols : null;
  const wlHasName = wlArr && wlArr.length > 0 && "name" in wlArr[0];
  ok("自选返回结构", !!wlArr && (wlArr.length === 0 || wlHasName),
     `symbols 是数组=${!!wlArr} 条目=${wlArr ? wlArr.length : "n/a"} 含name=${wlHasName}`);

  // 6. K 线（days 必须 >= 10）
  const kl = await call("/api/kline/daily?symbol=000001.SZ&days=120");
  ok("K线", Array.isArray(kl?.rows) && kl.rows.length > 0, `${kl?.rows?.length} 根`);

  const kFields = ["date", "open", "high", "low", "close", "volume"];
  const kMissing = kFields.filter((f) => !(f in kl.rows[0]));
  ok("K线字段对齐", kMissing.length === 0, kMissing.length ? "缺: " + kMissing : "");

  console.log("\n样例（Swift 展示逻辑）：");
  console.log(`  指数 ${first.name}: ${first.last_price.toFixed(2)} ${first.change_pct >= 0 ? "+" : ""}${first.change_pct.toFixed(2)}%`);
  console.log(`  个股 ${q.name}: ${q.close} ${(q.change_pct * 100 >= 0 ? "+" : "")}${(q.change_pct * 100).toFixed(2)}%`);
})();
